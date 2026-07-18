import { createElement } from 'lwc';
import MergeRecordList from 'c/mergeRecordList';
import getFieldSettings from '@salesforce/apex/MRG_MergeSettings_CTRL.getAllMergeFields';

jest.mock(
    'lightning/empApi',
    () => ({
        subscribe: jest.fn(() => Promise.resolve({})),
        unsubscribe: jest.fn(() => Promise.resolve({})),
        onError: jest.fn(),
        setDebugFlag: jest.fn(),
        isEmpEnabled: jest.fn(() => Promise.resolve(true))
    }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_MergeSettings_CTRL.getAllMergeFields',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_MergeSettings_CTRL.saveMergeFields',
    () => ({ default: jest.fn(() => Promise.resolve()) }),
    { virtual: true }
);

const ROWS = [
    { id: '1', name: 'EmailContact', label: 'Email', objectName: 'Contact', fieldName: 'Email', type: 'p', rule: 'Newest', relatedField: null, disable: false, conditions: [] },
    { id: '2', name: 'PhoneContact', label: 'Phone', objectName: 'Contact', fieldName: 'Phone', type: 't', rule: null, relatedField: null, disable: false, conditions: [] }
];

function flush() {
    return Promise.resolve();
}
function rowEls(el) {
    return el.shadowRoot.querySelectorAll('c-merge-single-record');
}
function addButton(el) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-button')).find(b => b.label === 'Add New Merge Field');
}

describe('c-merge-record-list', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    async function render() {
        const el = createElement('c-merge-record-list', { is: MergeRecordList });
        document.body.appendChild(el);
        getFieldSettings.emit(ROWS);
        await flush();
        await flush();
        return el;
    }

    it('renders one row per merge field setting', async () => {
        const el = await render();
        expect(rowEls(el).length).toBe(2);
    });

    it('cancelling an added field removes the empty placeholder row', async () => {
        const el = await render();
        addButton(el).dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(rowEls(el).length).toBe(3);

        rowEls(el)[2].dispatchEvent(new CustomEvent('notify', { detail: { actionType: 'cancel' } }));
        await flush();

        expect(rowEls(el).length).toBe(2); // regression: placeholder used to linger
    });

    it('adding twice does not stack two placeholder rows', async () => {
        const el = await render();
        addButton(el).dispatchEvent(new CustomEvent('click'));
        await flush();
        addButton(el).dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(rowEls(el).length).toBe(3);
    });

    // --- paging (#89): only a page of rows renders at a time ---------------------------------

    function manyRows(count) {
        const rows = [];
        for (let i = 0; i < count; i++) {
            rows.push({ id: String(i), name: `Field${i}Contact`, label: `Field${i}`, objectName: 'Contact', fieldName: `Field${i}`, type: 't', rule: null, relatedField: null, disable: false, conditions: [] });
        }
        return rows;
    }
    function pagerEl(el) {
        return el.shadowRoot.querySelector('c-pager');
    }

    it('renders only the first page of a large result set and shows the pager', async () => {
        const el = createElement('c-merge-record-list', { is: MergeRecordList });
        document.body.appendChild(el);
        getFieldSettings.emit(manyRows(60));
        await flush();
        await flush();
        expect(rowEls(el).length).toBe(25);
        expect(pagerEl(el)).not.toBeNull();
    });

    it('hides the pager when everything fits on one page', async () => {
        const el = await render();
        expect(pagerEl(el)).toBeNull();
    });

    it('changes page when the pager fires', async () => {
        const el = createElement('c-merge-record-list', { is: MergeRecordList });
        document.body.appendChild(el);
        getFieldSettings.emit(manyRows(60));
        await flush();
        await flush();
        pagerEl(el).dispatchEvent(new CustomEvent('page', { detail: 3 }));
        await flush();
        expect(rowEls(el).length).toBe(10); // 60 rows -> page 3 holds the last 10
    });

    it('jumps to the last page when a new field is added', async () => {
        const el = createElement('c-merge-record-list', { is: MergeRecordList });
        document.body.appendChild(el);
        getFieldSettings.emit(manyRows(60));
        await flush();
        await flush();
        addButton(el).dispatchEvent(new CustomEvent('click'));
        await flush();
        const rendered = rowEls(el);
        expect(rendered.length).toBe(11); // last page: 10 remaining rows + the new placeholder
    });
});
