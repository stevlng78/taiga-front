###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

ImportProjectSelectorDirective = () ->
    return {
        templateUrl:"projects/create/import-project-selector/import-project-selector.html",
        controller: "ImportProjectSelectorCtrl",
        controllerAs: "vm",
        bindToController: true,
        scope: {
            projects: '<',
            onCancel: '&',
            onSelectProject: '&',
            logo: '@',
            noProjectsMsg: '@',
            search: '@'
        }
    }

angular.module("taigaProjects").directive("tgImportProjectSelector", ImportProjectSelectorDirective)
