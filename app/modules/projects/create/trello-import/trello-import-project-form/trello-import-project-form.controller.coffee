###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

class TrelloImportProjectFormController
    @.$inject = [
        "tgCurrentUserService"
    ]

    constructor: (@currentUserService) ->
        @.canCreatePublicProjects = @currentUserService.canCreatePublicProjects()
        @.canCreatePrivateProjects = @currentUserService.canCreatePrivateProjects()

        @.projectForm = @.project.toJS()

        @.platformName = "Trello"
        @.projectForm.is_private = false
        @.projectForm.keepExternalReference = false

        if !@.canCreatePublicProjects.valid && @.canCreatePrivateProjects.valid
            @.projectForm.is_private = true

    checkUsersLimit: () ->
        @.limitMembersPrivateProject = @currentUserService.canAddMembersPrivateProject(@.members.size)
        @.limitMembersPublicProject = @currentUserService.canAddMembersPublicProject(@.members.size)

    saveForm: () ->
        @.onSaveProjectDetails({project: Immutable.fromJS(@.projectForm)})

    canCreateProject: () ->
        if @.projectForm.is_private
            return @.canCreatePrivateProjects.valid
        else
            return @.canCreatePublicProjects.valid

    isDisabled: () ->
        return !@.canCreateProject()

angular.module('taigaProjects').controller('TrelloImportProjectFormCtrl', TrelloImportProjectFormController)
