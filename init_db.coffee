sqlite3 = require('sqlite3').verbose()

db = new sqlite3.Database 'doubanDB.db'
createTables = ->
  new Promise (resolve, reject) ->
    db.serialize ->
      db.run """
        CREATE TABLE IF NOT EXISTS Subject
        (id TEXT PRIMARY KEY NOT NULL,
        url TEXT,
        subtype TEXT,
        tags TEXT,
        subjectId TEXT,
        title TEXT,
        directors TEXT,
        writers TEXT,
        casts TEXT,
        genres TEXT,
        countries TEXT,
        languages TEXT,
        pubdates TEXT,
        durations TEXT,
        episodes_count TEXT,
        aka TEXT,
        summary TEXT,
        rating REAL,
        rating_people INT,
        recommendations TEXT,
        imageId TEXT,
        FOREIGN KEY(imageId) REFERENCES File(id))
      """
      db.run """
        CREATE TABLE IF NOT EXISTS File(
          id TEXT PRIMARY KEY NOT NULL,
          source BLOB,
          subjectId TEXT
        );
      """
    db.serialize ->
      console.log "Created tables!!!".green
      resolve()
    db.close()

module.exports = createTables