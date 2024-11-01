###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "ImportProjectCtrl", ->
    $provide = null
    $controller = null
    mocks = {}

    _mockConfig = ->
        mocks.config = Immutable.fromJS({
            enableAsanaImporter: true,
            enableGithubImporter: true,
            enableJiraImporter: true,
            enableTrelloImporter: true,
        })

        $provide.value("$tgConfig", mocks.config)

    _mockTrelloImportService = ->
        mocks.trelloService = {
            authorize: sinon.stub(),
            getAuthUrl: sinon.stub()
        }

        $provide.value("tgTrelloImportService", mocks.trelloService)

    _mockJiraImportService = ->
        mocks.jiraService = {
            authorize: sinon.stub(),
            getAuthUrl: sinon.stub()
        }

        $provide.value("tgJiraImportService", mocks.jiraService)

    _mockGithubImportService = ->
        mocks.githubService = {
            authorize: sinon.stub(),
            getAuthUrl: sinon.stub()
        }

        $provide.value("tgGithubImportService", mocks.githubService)

    _mockAsanaImportService = ->
        mocks.asanaService = {
            authorize: sinon.stub(),
            getAuthUrl: sinon.stub()
        }

        $provide.value("tgAsanaImportService", mocks.asanaService)

    _mockWindow = ->
        mocks.window = {
            open: sinon.stub()
        }

        $provide.value("$window", mocks.window)

    _mockConfirm = ->
        mocks.confirm = {
            notify: sinon.stub()
        }

        $provide.value("$tgConfirm", mocks.confirm)

    _mockLocation = ->
        mocks.location = {
            search: sinon.stub()
        }

        $provide.value("$location", mocks.location)

    _mockRouteParams = ->
        mocks.routeParams = {
            platform: null
        }

        $provide.value("$routeParams", mocks.routeParams)

    _mockTgNavUrls = ->
        mocks.tgNavUrls = {
            resolve: sinon.stub()
        }

        $provide.value("$tgNavUrls", mocks.tgNavUrls)

    _mockTgAnalytics = ->
        mocks.tgAnalytics = {
            trackEvent: sinon.stub()
        }

        $provide.value("$tgAnalytics", mocks.tgAnalytics)

    _mocks = ->
        module (_$provide_) ->
            $provide = _$provide_

            _mockGithubImportService()
            _mockTrelloImportService()
            _mockJiraImportService()
            _mockAsanaImportService()
            _mockWindow()
            _mockConfirm()
            _mockLocation()
            _mockTgNavUrls()
            _mockRouteParams()
            _mockConfig()
            _mockTgAnalytics()

            return null

    _inject = ->
        inject (_$controller_) ->
            $controller = _$controller_

    _setup = ->
        _mocks()
        _inject()

    beforeEach ->
        module "taigaProjects"

        _setup()

    it "initialize form with trello", (done) ->
        searchResult = {
            oauth_verifier: 123,
            token: "token"
        }

        mocks.location.search.returns(searchResult)
        mocks.trelloService.authorize.withArgs(123).promise().resolve("token2")

        ctrl = $controller("ImportProjectCtrl")

        mocks.routeParams.platform = 'trello'

        ctrl.start().then () ->
            expect(mocks.location.search).have.been.calledWith({token: "token2"})

            done()

    it "initialize form with github", (done) ->
        searchResult = {
            code: 123,
            token: "token",
            from: "github"
        }

        mocks.location.search.returns(searchResult)
        mocks.githubService.authorize.withArgs(123).promise().resolve("token2")

        ctrl = $controller("ImportProjectCtrl")

        mocks.routeParams.platform = 'github'

        ctrl.start().then () ->
            expect(mocks.location.search).have.been.calledWith({token: "token2"})

            done()

    it "initialize form with asana", (done) ->
        searchResult = {
            code: 123,
            token: encodeURIComponent("{\"token\": 222}")
            from: "asana"
        }

        mocks.location.search.returns(searchResult)
        mocks.asanaService.authorize.withArgs(123).promise().resolve("token2")

        ctrl = $controller("ImportProjectCtrl")

        mocks.routeParams.platform = 'asana'

        ctrl.start().then () ->
            expect(mocks.location.search).have.been.calledWith({token: encodeURIComponent(JSON.stringify("token2"))})

            done()

    it "select trello import", () ->
        ctrl = $controller("ImportProjectCtrl")

        mocks.trelloService.getAuthUrl.promise().resolve("url")

        ctrl.select("trello").then () ->
            expect(mocks.window.open).have.been.calledWith("url", "_self")
