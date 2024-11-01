/*
 * This source code is licensed under the terms of the
 * GNU Affero General Public License found in the LICENSE file in
 * the root directory of this source tree.
 *
 * Copyright (c) 2021-present Kaleidos INC
 */

var common = require('./common');

var popover = module.exports;

var transition = 400;

async function selectPopoverItem(popover, item) {
    popover.$$('a').get(item).click();

    await browser.sleep(transition);
}

popover.wait = async function() {
    await browser.wait(async function() {
        return await $$('.popover.active').count() === 1;
    }, 3000);

    return $('.popover.active');
};

popover.open = async function(el, item, item2) {
    el.click();

    var pop = await popover.wait();

    if (item) {
        await selectPopoverItem(pop, item);

        if (item2) {
            pop = await popover.wait();
            await selectPopoverItem(pop, item2);
        }
    }

    return pop;
};
