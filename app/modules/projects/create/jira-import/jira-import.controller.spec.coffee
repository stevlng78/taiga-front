###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "JiraImportCtrl", ->
    $provide = null
    $controller = null
    mocks = {}

    _mockCurrentUserService = ->
        mocks.currentUserService = {
            canAddMembersPrivateProject: sinon.stub()
            canAddMembersPublicProject: sinon.stub()
        }

        $provide.value("tgCurrentUserService", mocks.currentUserService)

    _mockJiraImportService = ->
        mocks.jiraService = {
            fetchProjects: sinon.stub(),
            fetchUsers: sinon.stub(),
            importProject: sinon.stub()
        }

        $provide.value("tgJiraImportService", mocks.jiraService)

    _mockImportProjectService = ->
        mocks.importProjectService = {
            importPromise: sinon.stub()
        }

        $provide.value("tgImportProjectService", mocks.importProjectService)

    _mockConfirm = ->
        mocks.confirm = {
            loader: sinon.stub()
        }

        $provide.value("$tgConfirm", mocks.confirm)

    _mockTranslate = ->
        mocks.translate = {
            instant: sinon.stub()
        }

        $provide.value("$translate", mocks.translate)
    _mocks = ->
        module (_$provide_) ->
            $provide = _$provide_

            _mockJiraImportService()
            _mockConfirm()
            _mockTranslate()
            _mockImportProjectService()
            _mockCurrentUserService()

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

    it "start project selector", () ->
        ctrl = $controller("JiraImportCtrl")
        ctrl.startProjectSelector()

        expect(ctrl.step).to.be.equal('project-select-jira')
        expect(mocks.jiraService.fetchProjects).have.been.called

    it "on select project reload projects", (done) ->
        project = Immutable.fromJS({
            id: 1,
            name: "project-name"
        })

        mocks.jiraService.fetchUsers.promise().resolve()

        ctrl = $controller("JiraImportCtrl")

        promise = ctrl.onSelectProject(project)

        expect(ctrl.fetchingUsers).to.be.true

        promise.then () ->
            expect(ctrl.fetchingUsers).to.be.false
            expect(ctrl.step).to.be.equal('project-form-jira')
            expect(ctrl.project).to.be.equal(project)
            done()

    it "on save project details reload users", () ->
        project = Immutable.fromJS({
            id: 1,
            name: "project-name"
        })

        ctrl = $controller("JiraImportCtrl")
        ctrl.onSaveProjectDetails(project)

        expect(ctrl.step).to.be.equal('project-members-jira')
        expect(ctrl.project).to.be.equal(project)

    it "on select user init import", (done) ->
        users = Immutable.fromJS([
            {
                id: 0
            },
            {
                id: 1
            },
            {
                id: 2
            }
        ])

        loaderObj = {
            start: sinon.spy(),
            update: sinon.stub(),
            stop: sinon.spy()
        }

        projectResult = {
            id: 3,
            name: "name"
        }

        mocks.confirm.loader.returns(loaderObj)

        mocks.importProjectService.importPromise.promise().resolve()

        ctrl = $controller("JiraImportCtrl")
        ctrl.project = Immutable.fromJS({
            id: 1,
            name: 'project-name',
            description: 'project-description',
            keepExternalReference: false,
            is_private: true
        })


        mocks.jiraService.importProject.promise().resolve(projectResult)

        ctrl.startImport(users).then () ->
            expect(loaderObj.start).have.been.called
            expect(loaderObj.stop).have.been.called
            expect(mocks.jiraService.importProject).have.been.calledWith('project-name', 'project-description', 1, users, false, true)

            done()
