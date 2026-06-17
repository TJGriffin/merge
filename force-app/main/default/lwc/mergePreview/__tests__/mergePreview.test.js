import { createElement } from 'lwc';
import MergePreview from 'c/mergePreview';
import getPreviewRecord from '@salesforce/apex/MRG_Preview_CTRL.getPreviewRecord';

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
    'lightning/uiRecordApi',
    () => ({ updateRecord: jest.fn(() => Promise.resolve()) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_Preview_CTRL.getPreviewRecord',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

const RECORD = {
    recordId: 'mc1',
    keepRecord: { Id: '001A', Name: 'Acme', Phone: '111' },
    mergeRecord1: { Id: '001B', Name: 'Acme 2', Phone: '222' },
    mergeResultRecord: { Id: '001A', Name: 'Acme', Phone: '111' },
    fields: ['Phone', 'Name'],
    previewFields: [],
    mergeCandidate: { KeepName__c: 'Acme', MergeName__c: 'Acme 2', Status__c: 'New' }
};

function flush() {
    return Promise.resolve();
}

describe('c-merge-preview', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('builds the comparison table (field + keep + merge + result columns, one row per field)', async () => {
        const el = createElement('c-merge-preview', { is: MergePreview });
        el.recordId = 'mc1';
        document.body.appendChild(el);
        getPreviewRecord.emit(RECORD);
        await flush();
        await flush();

        const table = el.shadowRoot.querySelector('c-custom-datatable');
        expect(table).not.toBeNull();
        // fieldname + keepRecord + mergeRecord1 + mergeResultRecord (no merge2 for a pair)
        expect(table.columns.length).toBe(4);
        expect(table.data.length).toBe(2); // one row per previewed field
    });
});
