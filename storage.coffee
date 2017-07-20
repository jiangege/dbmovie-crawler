sqlite3 = require('sqlite3').verbose()
Guid = require 'Guid'
db = new sqlite3.Database 'doubanDB.db'
_ = require 'lodash'

saveSubject = ({
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
}) ->
  new Promise (resolve, reject) ->
    db.get """
      SELECT subjectId, id FROM Subject WHERE subjectId = $subjectId
    """, {
      $subjectId: subjectId
    }, (err, row) ->
      return reject err if err?
      if row?
        db.run """
          UPDATE Subject
          SET
            url = $url,
            title = $title,
            subtype = $subtype,
            imageId = $imageId,
            directors = $directors,
            writers = $writers,
            casts = $casts,
            genres = $genres,
            countries = $countries,
            languages = $languages,
            pubdates = $pubdates,
            durations = $durations,
            episodes_count = $episodes_count,
            aka = $aka,
            summary = $summary,
            rating = $rating,
            rating_people = $rating_people,
            recommendations = $recommendations
          WHERE subjectId = $subjectId
        """, {
          $subjectId: subjectId
          $url: url
          $title: title
          $subtype: subtype
          $imageId: imageId
          $directors: JSON.stringify directors
          $writers: JSON.stringify writers
          $casts: JSON.stringify casts
          $genres: JSON.stringify genres
          $countries: JSON.stringify countries
          $languages: JSON.stringify languages
          $pubdates: JSON.stringify pubdates
          $durations: JSON.stringify durations
          $episodes_count: episodes_count
          $aka: JSON.stringify aka
          $summary: summary
          $rating: rating
          $rating_people: rating_people
          $recommendations: JSON.stringify recommendations
        }, (err) ->
          return reject err if err?
          resolve row.id
      else 
        id = Guid.raw()
        db.run """
          INSERT INTO Subject (id, url, title, subjectId, subtype, 
            imageId, directors, writers, casts, genres, 
            countries, languages, pubdates, durations,
            episodes_count, aka, summary, rating, rating_people, recommendations
          )
          VALUES ($id, $url, $title, $subjectId, $subtype, 
            $imageId, $directors, $writers, $casts, $genres, 
            $countries,$languages, $pubdates, $durations, 
            $episodes_count, $aka, $summary, $rating, $rating_people, $recommendations
          );
        """, {
          $id: id
          $url: url
          $title: title
          $subjectId:  subjectId
          $subtype: subtype
          $imageId: imageId
          $directors: JSON.stringify directors
          $writers: JSON.stringify writers
          $casts: JSON.stringify casts
          $genres: JSON.stringify genres
          $countries: JSON.stringify countries
          $languages: JSON.stringify languages
          $pubdates: JSON.stringify pubdates
          $durations: JSON.stringify durations
          $episodes_count: episodes_count
          $aka: JSON.stringify aka
          $summary: summary
          $rating: rating
          $rating_people: rating_people
          $recommendations: JSON.stringify recommendations
        }, (err) ->
          return reject err if err?
          resolve id

addTag = ({ subjectId, tags }) ->
  new Promise (resolve, reject) ->
    db.get "SELECT tags FROM Subject WHERE subjectId = $subjectId"
    , { $subjectId: subjectId }, (err, row) ->
      return reject err if err?
      return resolve() unless row?
      try
        oldTags = JSON.parse row.tags
      catch e
        oldTags = []
      oldTags = if _.isArray(oldTags) then oldTags else []
      _.remove oldTags, (tag) -> _.includes tags, tag
      newTags = oldTags.concat tags
      newTagsJSON = JSON.stringify newTags
      db.run """
        UPDATE Subject
        SET tags = $tags
        WHERE subjectId = $subjectId
      """, {
        $subjectId: subjectId
        $tags: newTagsJSON
      }, (err) ->
        return reject err if err?
        resolve tags


existSubject = ({ subjectId })->
  new Promise (resolve, reject) ->
    db.get "SELECT subjectId FROM Subject WHERE subjectId = $subjectId"
    , { $subjectId: subjectId }, (err, row) ->
      return reject err if err?
      resolve row?

saveImage = ({
  subjectId
  imageBuffer
}) ->
  new Promise (resolve, reject) ->
    db.get """
      SELECT subjectId, id FROM File WHERE subjectId = $subjectId
    """, {
      $subjectId: subjectId
    }, (err, row) ->
      return reject err if err?
      if row?
        db.run """
          UPDATE File SET source = $source
          WHERE subjectId =  $subjectId;
        """, {
          $source: imageBuffer,
          $subjectId: subjectId
        }, (err) ->
          return reject err if err?
          resolve row.id
      else
        id = Guid.raw()
        db.run """
          INSERT INTO File (id, subjectId, source)
          VALUES ($id, $subjectId, $source);
        """, {
          $id: id
          $source: imageBuffer
          $subjectId: subjectId
        }, (err) ->
          return reject err if err?
          resolve id


module.exports = {
  saveImage
  addTag
  saveSubject
  existSubject
}