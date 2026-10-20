import { createElement } from 'lwc';
import KeepRecordRules from 'c/keepRecordRules';
import getPreferences from '@salesforce/apex/MRG_KeepRecordRules_CTRL.getPreferences';

jest.mock(
    'lightning/empApi',
    () => ({ subscribe: jest.fn(() => Promise.resolve({})), onError: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_KeepRecordRules_CTRL.getObjectFields',
    () => ({ default: jest.fn(() => Promise.resolve([
        { label: 'Relationship Manager', name: 'Relationship_Manager__c', type: 'STRING' },
        { label: 'Created Date', name: 'CreatedDate', type: 'DATETIME' }
    ])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_KeepRecordRules_CTRL.getKeepRecordRules',
    () => ({
        default: jest.fn(() => Promise.resolve([
            { id: 'r2', label: null, objectName: 'Account', order: 2, fieldName: 'CreatedDate', preference: 'Oldest', value: null, active: true },
            { id: 'r1', label: null, objectName: 'Account', order: 1, fieldName: 'Relationship_Manager__c', preference: 'HasValue', value: null, active: true }
        ]))
    }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_KeepRecordRules_CTRL.getPreferences',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
const mockSave = jest.fn(() => Promise.resolve('job'));
jest.mock(
    '@salesforce/apex/MRG_KeepRecordRules_CTRL.saveKeepRecordRules',
    () => ({ default: (...args) => mockSave(...args) }),
    { virtual: true }
);

const PREFERENCES = [
    { value: 'HasValue', label: 'has a value', needsValue: false },
    { value: 'Oldest', label: 'is the oldest (earliest date)', needsValue: false },
    { value: 'Equals', label: 'equals', needsValue: true }
];

function flush() {
    return new Promise((resolve) => setTimeout(resolve, 0));
}
function byLabel(el, tag, label) {
    return Array.from(el.shadowRoot.querySelectorAll(tag)).find((e) => e.label === label);
}
function byTitle(el, title, index) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-button-icon')).filter((e) => e.title === title)[index];
}
function fieldValues(el) {
    return Array.from(el.shadowRoot.querySelectorAll('c-merge-field-selector')).map((s) => s.value);
}

describe('c-keep-record-rules', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    async function renderForAccount() {
        const el = createElement('c-keep-record-rules', { is: KeepRecordRules });
        document.body.appendChild(el);
        getPreferences.emit(PREFERENCES);
        byLabel(el, 'lightning-combobox', 'Object').dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
        await flush();
        await flush();
        return el;
    }

    it('lists the stored rules in evaluation order', async () => {
        const el = await renderForAccount();
        expect(fieldValues(el)).toEqual(['Relationship_Manager__c', 'CreatedDate']);
    });

    it('sends the rules in order with UI-only keys stripped', async () => {
        const el = await renderForAccount();
        byLabel(el, 'lightning-button', 'Save').dispatchEvent(new CustomEvent('click'));
        await flush();

        expect(mockSave).toHaveBeenCalled();
        const args = mockSave.mock.calls[0][0];
        expect(args.objectType).toBe('Account');
        const payload = JSON.parse(args.jsonData);
        expect(payload).toHaveLength(2);
        expect(payload.map((r) => r.order)).toEqual([1, 2]);
        expect(payload.map((r) => r.fieldName)).toEqual(['Relationship_Manager__c', 'CreatedDate']);
        expect(Object.keys(payload[0]).sort()).toEqual(['active', 'fieldName', 'id', 'label', 'objectName', 'order', 'preference', 'value']);
    });

    it('moves a rule down and renumbers', async () => {
        const el = await renderForAccount();
        byTitle(el, 'Move down', 0).dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(fieldValues(el)).toEqual(['CreatedDate', 'Relationship_Manager__c']);
        byLabel(el, 'lightning-button', 'Save').dispatchEvent(new CustomEvent('click'));
        await flush();
        const payload = JSON.parse(mockSave.mock.calls[0][0].jsonData);
        expect(payload.map((r) => r.fieldName)).toEqual(['CreatedDate', 'Relationship_Manager__c']);
        expect(payload.map((r) => r.order)).toEqual([1, 2]);
    });

    it('removes a rule', async () => {
        const el = await renderForAccount();
        byTitle(el, 'Remove rule', 0).dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(fieldValues(el)).toEqual(['CreatedDate']);
    });

    it('adds a rule and shows the value box only for value preferences', async () => {
        const el = await renderForAccount();
        byLabel(el, 'lightning-button', 'Add Rule').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(fieldValues(el)).toHaveLength(3);
        expect(byLabel(el, 'lightning-input', 'Value')).toBeUndefined();
        const preference = Array.from(el.shadowRoot.querySelectorAll('lightning-combobox')).filter((c) => c.label === 'Preference')[2];
        preference.dispatchEvent(new CustomEvent('change', { detail: { value: 'Equals' } }));
        await flush();
        expect(byLabel(el, 'lightning-input', 'Value')).toBeDefined();
    });
});
