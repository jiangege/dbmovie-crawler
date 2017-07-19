rp = require 'request-promise-native'
cheerio = require 'cheerio'
model = require './sqlite-driver'
_ = require 'lodash'
jsonfile = require 'jsonfile'

crawlerState = 
  currPage: 0

config = null

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

searchSubject = ({
  type = ''
  tag = ''
  sort = 'recommend'
  page_limit = 321
  page_start = 0
}) ->
  rp.get {
    url: "https://movie.douban.com/j/search_subjects"
    qs: { type, tag, page_limit, sort, page_start }
    json: true
  }

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

getSubjectDetail = ({ subjectId }) ->
  url = "https://movie.douban.com/subject/#{subjectId}/"
  $ = cheerio.load(await rp.get { url })
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

  # imageBuffer = await requestFile image
  # imageId = await model.saveImage {
  #   subjectId
  #   imageBuffer
  # }

  # rImagePromises = recommendations.map (recommend) -> 
  #   new Promise (resolve, reject) ->
  #     requestFile recommend.url
  #       .then (imageBuffer) -> resolve imageBuffer
  #       .catch -> resolve null

  # pBufferArray = await Promise.all rImagePromises
  # for recommend, i in recommendations
  #   continue unless pBufferArray[i]?
  #   imageId = await model.saveImage {
  #     subjectId: recommend.subjectId
  #     imageBuffer: pBufferArray[i]
  #   }
  #   recommendations[i].imageId = imageId
  # _.remove recommendations, (recommend) -> not recommend.imageBuffer?

  {
    url
    title
    subjectId
    subtype
    imageId
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
  # id = await model.saveSubject {
  #   url
  #   title
  #   subjectId
  #   subtype
  #   imageId
  #   directors
  #   writers
  #   casts
  #   genres
  #   countries
  #   languages
  #   pubdates
  #   durations
  #   episodes_count
  #   aka
  #   summary
  #   rating
  #   rating_people
  #   recommendations
  # }
  # console.log id
  # return id

requestFile = (url) ->
  rp.get {
    url
    encoding: null
  }

init = (_config) ->
  config = _config

start = ->
  temp = jsonfile.readFileSync '/cache/temp.json'
  if temp?

stop = ->


module.export = {
  init
  start
  stop
}

getSubjectDetail({ subjectId: '26918285'})