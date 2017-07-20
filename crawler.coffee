rp = require 'request-promise-native'
cheerio = require 'cheerio'
storage = require './storage'
_ = require 'lodash'
jsonfile = require 'jsonfile'
require 'colors'
EventEmitter = require 'promise-events'

crawlerState = 
  tagIndex: 0
  subjectPageStart: 0

cacheState = null

config = 
  requestInterval: 2000
  retryLimit: 3
  pageLimit: 50
  timeout: 1000 * 10
  cachePath: null

crawlerEE = new EventEmitter

delay = (ms) ->
  ctr = null
  rej = null
  p = new Promise (resolve, reject) ->
    ctr = setTimeout resolve, ms
    rej = reject
  p.cancel = -> 
    clearTimeout ctr
    rej Error 'Cancelled'
  p

superRequest = (options, currRetryCount = 0) ->
  await delay config.requestInterval
  try
    options = { options..., timeout: config.timeout }
    await rp.get options
  catch e
    currRetryCount++
    throw e if currRetryCount > 3
    console.error "#{options.url} - Ready to retry #{currRetryCount} times...".red
    superRequest options, currRetryCount
  
searchTags = ->
  types = ['movie', 'tv']
  tags = []
  for type in types
    data = await superRequest {
      url: "https://movie.douban.com/j/search_tags?type=#{type}"
      json: true
    }
    _tags = data.tags.map (tag) -> { title: tag, type }
    tags = tags.concat _tags
  return _.uniq tags

searchSubjects = ({
  type = ''
  tag = ''
  sort = 'recommend'
  page_limit = 50
  page_start = 0
}) ->
  data = await superRequest {
    url: "https://movie.douban.com/j/search_subjects"
    qs: { type, tag, page_limit, sort, page_start }
    json: true
  }
  if data?.subjects? then data.subjects else []

getAttr = (keyword, info, brackets = null, defaultVal = []) ->
  try
    regexp = new RegExp("#{keyword}: (([\\u4e00-\\u9fa5]|.)+)\\n").exec(info)
    if not regexp?
      return defaultVal
    vals = regexp[1].split('/').map (str) ->
      if brackets?
        try
          ary = str.split '('
          d = ary[0]
          d2 = null
          if ary[1]?
            d2 = ary[1].split(')')[0].trim()
          return { 
            "#{brackets.key}" : d.trim()
            "#{brackets.key2}" : d2 
          } 
        catch e 
          console.error e
          return {}
      else
        return str.trim()
    vals
  catch e
    console.error keyword, e
    return defaultVal

searchSubject = ({ subjectId }) ->
  url = "https://movie.douban.com/subject/#{subjectId}/"
  $ = cheerio.load(await superRequest { url })
  title = $('#wrapper #content span[property="v:itemreviewed"]').text().trim()
  image = $('.article .subject #mainpic .nbgnbg img[rel="v:image"]').attr 'src'
  type = $('a.bn-sharing').data 'type'
  subtype = if type is '电影' then 'movie' else 'tv'
  info = $('.article .subject #info').text()
  directors = getAttr '导演', info
  writers = getAttr '编剧', info
  casts = getAttr '主演', info
  genres = getAttr '类型', info
  countries = getAttr '制片国家/地区', info
  languages = getAttr '语言', info
  if subtype is 'tv'
    pubdates = getAttr '首播', info, { key: 'date', key2: 'country' }
    durations = getAttr '单集片长', info, { key: 'duration', key2: 'country' }
    episodes_count = parseInt(getAttr '集数', info, null, 0)
  else if subtype is 'movie'
    pubdates = getAttr '上映日期', info, { key: 'date', key2: 'country' }
    durations = getAttr '片长', info, { key: 'duration', key2: 'country' }
 
  aka = getAttr '又名', info, { key: 'name', key2: 'country' }
  summary = $('#link-report span[property="v:summary"]').text().trim()
  rating = parseFloat($('strong.ll.rating_num[property="v:average"]').text().trim())
  rating_people = parseInt($('a.rating_people [property="v:votes"]').text().trim())
  recommendations = []
  $('.recommendations-bd dl').each (i, dl) ->
    rTitle = $('dd a', dl).text()
    rSubjectUrl = $('dd a', dl).attr 'href'
    rUrl = $('dt img', dl).attr 'src'
    rSubjectId = /subject\/(\w+)?\//.exec(rSubjectUrl)[1]
    recommendations.push { title: rTitle, url: rUrl, subjectId: rSubjectId } 

  {
    url
    title
    subjectId
    subtype
    image
    directors
    writers
    casts
    genres
    countries
    languages
    pubdates
    durations
    episodes_count
    aka
    summary
    rating
    rating_people
    recommendations
  }

requestFile = (url) ->
  superRequest {
    url
    encoding: null
  }

runTagsQueue = (tags, tagIndex, hasSubjects = false) ->
  if tagIndex > tags.length - 1
    if hasSubjects is true
      crawlerState.tagIndex = 0
      crawlerState.subjectPageStart += config.pageLimit
      await runTagsQueue tags, crawlerState.tagIndex, false
    else
      return
  else
    tag = tags[tagIndex]
    console.log """
      Runing type: #{tag.type}
      Runing tag: #{tag.title}
    """
    crawlerState.tagIndex = tagIndex
    await saveState()
    subjects = await runSearchSubjectQueue tag, crawlerState.subjectPageStart
    await runTagsQueue tags, ++tagIndex, subjects.length > 0

runSearchSubjectQueue = (tag, subjectPageStart) ->
  subjects = await searchSubjects {
    tag: tag.title
    type: tag.type
    page_limit: config.pageLimit
    page_start: subjectPageStart
  }
    .catch (e) -> console.error "Failed to get subjects from #{tag.title}".red
  if subjects?
    for subject in subjects
      await saveSubject subject, tag.title
    subjects
  else []

init = (_config = {}) ->
  config = { config..., _config... }
  try
    cacheState = jsonfile.readFileSync config.cachePath
  catch e
    cacheState = {}
  crawlerState = { crawlerState..., cacheState... }

saveSubject = (subject, tag) ->
  exist = await storage.existSubject { subjectId: subject.id }
  if exist is true
     console.info "The subject already exists #{subject.id}".yellow
  else 
    detail = await searchSubject subjectId: subject.id
    {
      image
      recommendations
      subjectId
    } = detail
    imageBuffer = await requestFile image
      .catch (e) -> console.error "Failed to get image #{image}".red
    return unless imageBuffer?
    imageId = await storage.saveImage {
      subjectId
      imageBuffer
    }
      .catch (e) -> console.error "Failed to store image #{image}".red
    return unless imageId?

    rImagePromises = recommendations.map (recommend) -> 
      new Promise (resolve, reject) ->
        requestFile recommend.url
          .then (imageBuffer) -> resolve imageBuffer
          .catch -> resolve null

    pBufferArray = await Promise.all rImagePromises
    for recommend, i in recommendations
      continue unless pBufferArray[i]?
      _imageId = await storage.saveImage {
        subjectId: recommend.subjectId
        imageBuffer: pBufferArray[i]
      }
        .catch (e) -> console.error "Failed to store image #{recommend.url}".red
      continue unless _imageId?
      recommend.imageId = _imageId
    _.remove recommendations, (recommend) -> not recommend.imageId?
    id = await storage.saveSubject { detail..., imageId}
      .catch (e) -> console.error "Failed to store subject #{id}".red
    return unless id?
    console.log "Successfully store subject #{detail.subjectId} #{detail.title}".green
  
  tags = await storage.addTag { 
    subjectId: subject.id
    tags: [tag]
  }
    .catch (e) -> console.error "Failed to store tag #{tag} to subject #{subject.id}".red
  if tags?
    console.log "Successfully add tag to subject #{subject.id}".green

saveState = ->
  new Promise (resolve, reject) ->
    jsonfile.writeFile config.cachePath, crawlerState, {spaces: 2}, (err) -> 
      if err?
        console.error "Can not save state to cache \n #{err}".red
      resolve()

start = ->
  tags = await searchTags()      
  await runTagsQueue tags, crawlerState.tagIndex

module.exports = {
  init
  start
}