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
    keepRecord: {
        Id: '001A', Name: 'Acme', Phone: '111', Industry: 'Tech',
        CreatedDate: '2020-01-01T00:00:00.000Z', LastModifiedDate: '2021-01-01T00:00:00.000Z'
    },
    mergeRecord1: {
        Id: '001B', Name: 'Acme 2', Phone: '222', Industry: 'Tech',
        CreatedDate: '2019-01-01T00:00:00.000Z', LastModifiedDate: '2020-06-01T00:00:00.000Z'
    },
    mergeResultRecord: {
        Id: '001A', Name: 'Acme', Phone: '111', Industry: 'Tech', Website: 'acme.com',
        CreatedDate: '2020-01-01T00:00:00.000Z', LastModifiedDate: '2021-01-01T00:00:00.000Z'
    },
    fields: ['Phone', 'Name'],
    matchingFields: ['Industry'],
    // a fallback-routed value: the losing Description landed in the (otherwise empty) Website field
    fieldHistory: [{ TargetField__c: 'Website', MergeValueType__c: 'Description' }],
    previewFields: [],
    mergeCandidate: { KeepName__c: 'Acme', MergeName__c: 'Acme 2', Status__c: 'New' }
};

function flush() {
    return Promise.resolve();
}
function fieldNames(table) {
    return table.data.map(r => r.fieldname);
}
async function render() {
    const el = createElement('c-merge-preview', { is: MergePreview });
    el.recordId = 'mc1';
    document.body.appendChild(el);
    getPreviewRecord.emit(RECORD);
    await flush();
    await flush();
    return el;
}

describe('c-merge-preview', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('builds the comparison table (field + keep + merge + result columns)', async () => {
        const el = await render();
        const table = el.shadowRoot.querySelector('c-custom-datatable');
        expect(table).not.toBeNull();
        // fieldname + keepRecord + mergeRecord1 + mergeResultRecord (no merge2 for a pair)
        expect(table.columns.length).toBe(4);
    });

    it('shows Id as the first row and CreatedDate/LastModifiedDate as the last two rows', async () => {
        const el = await render();
        const names = fieldNames(el.shadowRoot.querySelector('c-custom-datatable'));
        expect(names[0]).toBe('Id');
        expect(names.slice(-2)).toEqual(['CreatedDate', 'LastModifiedDate']);
    });

    it('hides matching fields by default and reveals them when the checkbox is checked', async () => {
        const el = await render();
        const table = el.shadowRoot.querySelector('c-custom-datatable');
        expect(fieldNames(table)).not.toContain('Industry');

        const checkbox = el.shadowRoot.querySelector('lightning-input');
        checkbox.checked = true;
        checkbox.dispatchEvent(new CustomEvent('change'));
        await flush();
        expect(fieldNames(table)).toContain('Industry');
    });

    it('shows fallback-routed fields and highlights only the merge-result cell', async () => {
        const el = await render();
        const table = el.shadowRoot.querySelector('c-custom-datatable');
        const fallbackRow = table.data.find(r => r.fieldname === 'Website');
        expect(fallbackRow).toBeDefined();
        expect(fallbackRow.mergeResultRecord).toBe('acme.com');
        expect(fallbackRow.mergeResultStyle).toContain('background-color');

        const phoneRow = table.data.find(r => r.fieldname === 'Phone');
        expect(phoneRow.mergeResultStyle).toBe('');
    });

    it('never makes the system rows (Id/dates) editable', async () => {
        const el = await render();
        const table = el.shadowRoot.querySelector('c-custom-datatable');
        ['Id', 'CreatedDate', 'LastModifiedDate'].forEach(name => {
            expect(table.data.find(r => r.fieldname === name).editable).toBe(false);
        });
    });
});
