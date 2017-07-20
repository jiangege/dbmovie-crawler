init_db = require './init_db'
crawler = require './crawler'

do ->
  crawler.init require './config'
  await init_db()
  crawler.start()