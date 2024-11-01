###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

taiga = @.taiga
startswith = @.taiga.startswith
bindMethods = @.taiga.bindMethods

module = angular.module("taigaEvents", [])


class EventsService
    constructor: (@win, @log, @config, @auth, @liveAnnouncementService, @rootScope) ->
        bindMethods(@)

    initialize: (sessionId) ->
        @.sessionId = sessionId
        @.subscriptions = {}
        @.connected = false
        @.error = false
        @.pendingMessages = []
        @.reconnectTryInterval = @config.get("eventsReconnectTryInterval", 10000)
        @.maxConnectionErrors = @config.get("eventsMaxConnectionErrors", 5)
        @.errors = 0

        @.missedHeartbeats = 0
        @.heartbeatInterval = null

        if @win.WebSocket is undefined
            @log.info "WebSockets not supported on your browser"

    setupConnection: ->
        @.stopExistingConnection()

        url = @config.get("eventsUrl")

        # This allows disable events in case
        # url is not found on the configuration.
        return if not url

        # This allows relative urls in configuration.
        if not startswith(url, "ws:") and not startswith(url, "wss:")
            loc = @win.location
            scheme = if loc.protocol == "https:" then "wss:" else "ws:"
            path = _.trimStart(url, "/")
            url = "#{scheme}//#{loc.host}/#{path}"

        @.error = false
        @.ws = new @win.WebSocket(url)
        @.ws.addEventListener("open", @.onOpen)
        @.ws.addEventListener("message", @.onMessage)
        @.ws.addEventListener("error", @.onError)
        @.ws.addEventListener("close", @.onClose)

    stopExistingConnection: ->
        if @.ws is undefined
            return

        @.ws.removeEventListener("open", @.onOpen)
        @.ws.removeEventListener("close", @.onClose)
        @.ws.removeEventListener("error", @.onError)
        @.ws.removeEventListener("message", @.onMessage)
        @.stopHeartBeatMessages()
        @.ws.close()

        delete @.ws

    notifications: ->
        @.subscribe null, 'notifications', (data) =>
            @liveAnnouncementService.show(data.title, data.desc)
            @rootScope.$digest()

    liveNotifications: ->
        if not @.auth.userData?
            return
        userId = @.auth.userData.get('id')

        subscribe = () =>
            @.subscribe null, "live_notifications.#{userId}", (data) =>
                notification = new Notification(data.title, {
                    icon: "/#{window._version}/images/favicon.png",
                    body: data.body,
                    tag: data.id
                })
                notification.onshow = () =>
                    if data.timeout and data.timeout > 0
                        setTimeout =>
                            notification.close()
                        ,
                            data.timeout

                if data.url
                    notification.onclick = () =>
                        window.open data.url
        if !(window.Notification)
            @log.info("This browser does not support desktop notification")
        else if Notification.permission == "granted"
            subscribe()
        else if Notification.permission != 'denied'
            Notification.requestPermission (permission) =>
              if (permission == "granted")
                  subscribe()

    webNotifications: ->
        if not @.auth.userData?
            return
        userId = @.auth.userData.get('id')

        routingKey = "web_notifications.#{userId}"
        randomTimeout = taiga.randomInt(700, 1000)
        @.subscribe null, routingKey, (data) =>
            @rootScope.$broadcast "notifications:new"

    ###########################################
    # Heartbeat (Ping - Pong)
    ###########################################
    # See  RFC https://tools.ietf.org/html/rfc6455#section-5.5.2
    #      RFC https://tools.ietf.org/html/rfc6455#section-5.5.3
    startHeartBeatMessages: ->
        return if @.heartbeatInterval

        maxMissedHeartbeats =  @config.get("eventsMaxMissedHeartbeats", 5)
        heartbeatIntervalTime = @config.get("eventsHeartbeatIntervalTime", 60000)

        @.missedHeartbeats = 0
        @.heartbeatInterval = setInterval(() =>
            try
                if @.missedHeartbeats >= maxMissedHeartbeats
                    throw new Error("Too many missed heartbeats PINGs.")

                @.missedHeartbeats++
                @.sendMessage({cmd: "ping"})
                @log.debug("HeartBeat send PING")
            catch e
                @log.error("HeartBeat error: " + e.message)
                @.setupConnection()
        , heartbeatIntervalTime)

        @log.debug("HeartBeat enabled")

    stopHeartBeatMessages: ->
        return if not @.heartbeatInterval

        clearInterval(@.heartbeatInterval)
        @.heartbeatInterval = null

        @log.debug("HeartBeat disabled")

    processHeartBeatPongMessage: (data) ->
        @.missedHeartbeats = 0
        @log.debug("HeartBeat received PONG")

    ###########################################
    # Messages
    ###########################################
    serialize: (message) ->
        if _.isObject(message)
            return JSON.stringify(message)
        return message

    sendMessage: (message) ->
        @.pendingMessages.push(message)

        if not @.connected
            return

        messages = _.map(@.pendingMessages, @.serialize)
        @.pendingMessages = []

        for msg in messages
            @.ws.send(msg)

    processMessage: (data) =>
        routingKey = data.routing_key

        if not @.subscriptions[routingKey]?
            return

        subscription = @.subscriptions[routingKey]

        if subscription.scope
            subscription.scope.$apply ->
                subscription.callback(data.data)

        else
            subscription.callback(data.data)

    ###########################################
    # Subscribe and Unsubscribe
    ###########################################
    subscribe: (scope, routingKey, callback, options) ->
        if @.error
            return

        @log.debug("Subscribe to: #{routingKey}")
        subscription = {
            scope: scope,
            routingKey: routingKey,
            callback: callback
        }

        message = {
            "cmd": "subscribe",
            "routing_key": routingKey
        }

        if options
            message.options = options

        @.subscriptions[routingKey] = subscription
        @.sendMessage(message)

        scope.$on("$destroy", => @.unsubscribe(routingKey)) if scope

    unsubscribe: (routingKey) ->
        if @.error
            return

        @log.debug("Unsubscribe from: #{routingKey}")

        message = {
            "cmd": "unsubscribe",
            "routing_key": routingKey
        }

        @.sendMessage(message)

    ###########################################
    # Event listeners
    ###########################################
    onOpen: ->
        @.connected = true

        @log.debug("WebSocket connection opened")
        token = @auth.getToken()

        message = {
            cmd: "auth"
            data: {token: token, sessionId: @.sessionId}
        }

        @.sendMessage(message)
        @.startHeartBeatMessages()
        @.notifications()
        @.liveNotifications()
        @.webNotifications()

    onMessage: (event) ->
        @log.debug "WebSocket message received: #{event.data}"

        data = JSON.parse(event.data)

        if data.cmd == "pong"
            @.processHeartBeatPongMessage(data)
        else
            @.processMessage(data)

    onError: (error) ->
        @log.error("WebSocket error: #{error}")
        @.error = true
        @.errors++

        if @.errors < @.maxConnectionErrors
            setTimeout(@.setupConnection, @.randomTryInterval())
        else
            @log.error("Events are disabled: the maximum number of connection errors has been reached.")

    onClose: ->
        @log.debug("WebSocket closed.")
        @.connected = false
        @.stopHeartBeatMessages()

        if !@.error
            setTimeout(@.setupConnection, @.randomTryInterval())

    randomTryInterval: ->
        min = @.reconnectTryInterval / 2
        max = @.reconnectTryInterval

        return Math.floor(Math.random() * (max - min + 1)) + min



class EventsProvider
    setSessionId: (sessionId) ->
        @.sessionId = sessionId

    $get: ($win, $log, $conf, $auth, liveAnnouncementService, $rootScope) ->
        service = new EventsService($win, $log, $conf, $auth, liveAnnouncementService, $rootScope)
        service.initialize(@.sessionId)
        return service

    @.prototype.$get.$inject = [
        "$window",
        "$log",
        "$tgConfig",
        "$tgAuth",
        "tgLiveAnnouncementService",
        "$rootScope"
    ]

module.provider("$tgEvents", EventsProvider)
