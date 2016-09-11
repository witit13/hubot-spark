///
Copyright 2016 Anthony Shaw, Dimension Data

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
///
util = require('util');
Robot   = require('hubot').Robot
Adapter = require('hubot').Adapter
TextMessage = require('hubot').TextMessage

HTTPS        = require 'https'
EventEmitter = require('events').EventEmitter
Spark       = require('csco-spark')

class SparkAdapter extends Adapter
  constructor: (robot) ->
    super

  send: (envelope, strings...) ->
    user = if envelope.user then envelope.user else envelope
    strings.forEach (str) =>
      @prepare_string str, (message) =>
        @bot.send user,message
 
  reply: (envelope, strings...) ->
    user = if envelope.user then envelope.user else envelope
    strings.forEach (str) =>
      @prepare_string str,(message) =>
        @bot.reply user,message
 
  prepare_string: (str, callback) ->
    text = str
    messages = [str]
    messages.forEach (message) =>
      callback message

  run: ->
    self = @
    options =
     api_uri: process.env.HUBOT_SPARK_API_URI or "https://api.ciscospark.com/v1"
     access_token: process.env.HUBOT_SPARK_ACCESS_TOKEN
     bot_id      : process.env.HUBOT_SPARK_BOT_ID
    bot = new SparkRealtime(options, @robot)
    @robot.logger.debug "Created bot, setting up listeners"
    
    @robot.logger.debug "Done with custom bot logic"
    @bot = bot
    @emit 'connected'

exports.use = (robot) ->
  new SparkAdapter robot

class SparkRealtime extends EventEmitter
  self = @
  room_ids = []
  constructor: (options, robot) ->
    if options.access_token?
      @robot = robot
      try
        @robot.logger.info "Trying connection to #{options.api_uri}"
        @spark = Spark
          uri: options.api_uri
          token: options.access_token
        @robot.logger.info "Created connection instance to spark"
      catch e
        throw new Error "Failed to connect #{e.message}"
        
      @robot.logger.debug "Completed adding rooms to list"

      @robot.router.post "/webhook", (req, res) =>
        @robot.logger.debug "received message id #{req.body.data.id} from #{req.body.data.personEmail}"
        if req.body.actorId != options.bot_id
          @spark.getMessage(req.body.data.id).then (body) =>
            message = JSON.parse(body)
            text = message.text
            user_name = message.personEmail
            user =
              name: message.personEmail
              id: message.personId
              room: message.roomId
            @robot.logger.debug "received #{text} from #{user.name} message:"+util.inspect(message, false, null)
            @robot.receive new TextMessage user, text

     else
       throw new Error "Not enough parameters provided. I need an access token"
 
  ## Spark API call methods
 
  send: (user, message, room) ->
    @robot.logger.debug "Sending message"
    @robot.logger.debug "send message to room #{user.room} with text #{message}"
    @spark.sendMessage
      roomId: user.room
      text: message
 
  reply: (user, message) ->
    @robot.logger.debug "Replying to message for #{user}"
    if user
      @robot.logger.debug "reply message to #{user} with text #{message}"
      @spark.sendMessage
        text: message
        roomId: user.room
