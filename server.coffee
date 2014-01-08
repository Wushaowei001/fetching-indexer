crypto = require 'crypto'
express = require 'express'
monk = require 'monk'

app = express()
app.use express.logger()
app.use express.urlencoded()
app.use express.json()

indexedResponse = (req, res) ->
  (e, r) ->
    if e
      console.error e
      res.send 500, e
    else
      res.send (if r._version is 1 then 201 else 200), 'Document saved.'

es = new require('elasticsearch').Client
  host: 'localhost:9200', log: 'trace'

users = monk('localhost:3003/meteor').get('users')

app.post 'sessions', (req, res) ->
  email = req.body.email

  users.findOne('emails.address': email)
    .on 'success', (user) ->


app.post '/documents', (req, res) ->
  {url, title, body, token} = req.body
  updatedAt = new Date()

  console.log token
  console.log url

  id = crypto.createHash('md5').update(url).digest('hex')

  users.findOne('services.resume.loginTokens.token': token)
    .on 'success', (user) ->
      console.log user
      userId = user._id

      es.exists
        index: 'documents'
        type: 'document'
        routing: userId,
        id: id
      , (error, exists) ->

        console.log "Indexing " + url

        if exists is true
          es.update
            index: 'documents'
            routing: userId,
            type: 'document',
            id: id
            body:
              doc:
                {body, title, userId, updatedAt}
          , indexedResponse(req, res)
        else
          es.create
            index: 'documents'
            routing: userId,
            type: 'document',
            id: id
            body:
              {body, title, url, userId, updatedAt, createdAt: updatedAt}
          , indexedResponse(req, res)

app.listen 3000