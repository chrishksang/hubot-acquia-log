# Description:
#   Integration with Acquia's Logstream API.
#   It will connect to the logstream once the bot starts then there
#   are more commands to control streaming of logs.
#   @todo: refactor into some kind of saner class based thing
#
# Dependencies:
#   ws
#   q
#
# Configuration:
#   HUBOT_ACQUIA_LOG_USER: acquia cloud user
#   HUBOT_ACQUIA_LOG_TOKEN: auth token for the user
#   HUBOT_ACQUIA_LOG_SITE: acquia cloud site
#   HUBOT_ACQUIA_LOG_SITE_ENV: environment of the site
#   HUBOT_ACQUIA_LOG_ROOM: chat room to message into
#
# Commands:
#   hubot acquia log connect - connect to logstream
#   hubot acquia log disconnect - disconnect from logstream
#   hubot acquia log status - hubot's connection to acquia status
#   hubot acquia log enable <type> - enable streaming logs of <type>
#   hubot acquia log list types - list log types which can be streamed
#   hubot acquia log list-enabled - show which logs are being streamed
#   hubot acquia log disable <type> - disable streaming logs of <type>
#   hubot acquia log start <type> - start displaying logs. This may output a lot of stuff...
#   hubot acquia log stop <type> - stop displaying logs.
#
# Notes:
#   External scripts can use the event "acquiaLogMessageLine" which
#   receives the parameters text, type, server and display_time.
#

WebSocket = require 'ws'
Q = require 'q'

module.exports = (robot) ->

  # Object to hold websocket connection object.
  ws = {}

  # Config variables.
  config =
    user: process.env.HUBOT_ACQUIA_LOG_USER
    token: process.env.HUBOT_ACQUIA_LOG_TOKEN
    site: process.env.HUBOT_ACQUIA_LOG_SITE
    env: process.env.HUBOT_ACQUIA_LOG_SITE_ENV
    room: process.env.HUBOT_ACQUIA_LOG_ROOM
    enabled: process.env.HUBOT_ACQUIA_LOG_ENABLED

  # Local object to store data on available servers and logs.
  available = []

  # Types which can be enabled.
  enabled = [
    "apache-request"
    "drupal-request"
    "drupal-watchdog"
    "php-error"
  ]

  # Whether we are streaming messages or not.
  streaming = false

  # Initiate connection to logstream.
  init = ()->
    url = "https://cloudapi.acquia.com/v1/sites/#{config.site}/envs/#{config.env}/logstream.json"
    deferred = Q.defer()
    token = new Buffer("#{config.user}:#{config.token}").toString('base64')

    # Get the details for setting up logstream.
    robot.http(url)
    .header('Authorization', "Basic #{token}")
    .get() (err, res, body)->
      if res.code is 200
        data = JSON.parse body
        deferred.resolve data
      else
        deferred.reject err

    return deferred.promise

  # Once we have a websocket, bind the events.
  bind = (ws)->
    ws.on 'error', (error)->
      robot.logger.error "error: #{error}"

    ws.on 'open', ()->
      robot.logger.info "Opened connection to Acquia Logstream at #{data.url}"
      # Once connected we need to send the set up message.
      # This will bring back a list of servers and the available logs.
      ws.send data.msg

    ws.on 'message', (msg, flags)->
      robot.logger.debug "onmessage msg: #{msg}"
      msgData = JSON.parse msg
      switch msgData.cmd
        # Acquia will tell us what logs we can use.
        when "available"
          available.push msgData
        when "success"
          robot.logger.debug msgData.msg
        when "line"
          if streaming
            robot.messageRoom config.room, "#{msgData.disp_time}. Type: #{msgData.log_type}. Server: #{msgData.server}. Text: #{msgData.text}"
          robot.emit "acquiaLogMessageLine", msgData.text, msgData.log_type, msgData.server, msgData.disp_time
        when "enabled"
          robot.logger.info msgData
          if msgData.enabled.length
            robot.messageRoom config.room, "Server #{msgData.server} has #{msgData.enabled.join ', '} logs streaming enabled"

    ws.on 'close', (code, msg)->
      robot.logger.debug code
      robot.logger.debug msg

  # Connect and bind all the events.
  connect = ()->
    return init().then((data)->
      ws = new WebSocket data.url
      bind()
      return true
    ,(error)->
      robot.logger.error error
      return error
    )

  # Enable or disable logs.
  robot.respond /acquia log (disable|enable) (.*)/i, (msg)->
    command = msg.match[1]
    logType = msg.match[2].trim()

    if logType not in enabled
      return msg.send "I can't #{command} logs of type #{logType}"
    try
      for server in available
        if server.type is logType
          ws.send JSON.stringify {"cmd": "#{command}", "type": "#{logType}", "server": "#{server.server}"}
      msg.send "OK. I've #{command}d streaming logs of #{logType}."
    catch error
      msg.send "I couldn't do that, because of this error: #{error}."

  robot.respond /acquia log list-enabled/i, (msg)->
    try
      ws.send JSON.stringify {"cmd": "list-enabled"}
      msg.send "OK. I am listing the enabled logs."
    catch error
      msg.send "I couldn't do that, because of this error: #{error}."

  robot.respond /acquia log (start|stop)/i, (msg)->
    verb = msg.match[1]
    streaming = verb is 'start'
    msg.send "OK. Streaming Acquia logs will #{verb} from now."

  robot.respond /acquia log list types/i, (msg)->
    msg.reply "I can stream logs of these types: #{enabled.join ', '}"

  robot.respond /acquia log connect/i, (msg)->
    msg.reply "OK. I've connected!"

  robot.respond /acquia log disconnect/i, (msg)->
    msg.reply "OK. I've disconnected!"

  robot.respond /acquia log status/i, (msg)->
    msg.reply "My logstream status is: this"

  # Initiate everything on load.
  connect()
