rp = require 'request-promise-native'
cheerio = require 'cheerio'

searchSubject = ({
  type = ''
  tag = ''
  sort = 'recommend'
  page_limit = 20
  page_start = 0
} = {}) ->
  res = await rp.get {
    url: "https://movie.douban.com/j/search_subjects"
    qs: { type, tag, page_limit, sort, page_start }
    json: true
  }
  console.log res.subjects[0].id
  detail = await getSubjectDetail({ id: res.subjects[0].id })
  console.log detail

getSubjectDetail = ({ id }) ->
  $ = cheerio.load(await rp.get {
    url: "https://movie.douban.com/subject/#{id}/"
  })
  title = $('#wrapper #content span[property="v:itemreviewed"]').text()
  image = $('.article .subject #mainpic .nbgnbg img[rel="v:image"]').attr 'src'
  info = $('.article .subject #info').text()
  console.log /导演: (([\u4e00-\u9fa5]|.)+)\n/.exec(info)[1]
  console.log /编剧: (([\u4e00-\u9fa5]|.)+)\n/.exec(info)[1]
  console.log /主演: (([\u4e00-\u9fa5]|.)+)\n/.exec(info)[1]
  console.log /类型: (([\u4e00-\u9fa5]|.)+)\n/.exec(info)[1]
  console.log /制片国家\/地区: (([\u4e00-\u9fa5]|.)+)\n/.exec(info)[1]
  console.log /语言: (([\u4e00-\u9fa5]|.)+)\n/.exec(info)[1]
  console.log /上映日期: (([\u4e00-\u9fa5]|.)+)\n/.exec(info)[1]
  console.log /片长: (([\u4e00-\u9fa5]|.)+)\n/.exec(info)[1]
  console.log /又名: (([\u4e00-\u9fa5]|.)+)\n/.exec(info)[1]
  # console.log $('.article .subject #info').html()

getSubjectDetail({ id: 26387939 })