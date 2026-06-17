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
});
