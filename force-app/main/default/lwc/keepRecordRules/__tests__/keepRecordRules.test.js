import { createElement } from 'lwc';
import KeepRecordRules from 'c/keepRecordRules';

jest.mock(
    'lightning/empApi',
    () => ({ subscribe: jest.fn(() => Promise.resolve({})), onError: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_KeepRecordRules_CTRL.getObjectFields',
    () => ({ default: jest.fn(() => Promise.resolve([{ label: 'Email', name: 'Email', type: 'STRING' }])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_KeepRecordRules_CTRL.getKeepRecordRules',
    () => ({
        default: jest.fn(() => Promise.resolve([
            { id: 'r1', label: 'Keep1', objectName: 'Account', order: 1, filterLogic: '1', conditions: [{ fieldName: 'Email', operator: 'equals', value: 'x' }] }
        ]))
    }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_KeepRecordRules_CTRL.getOperators',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
const mockSave = jest.fn(() => Promise.resolve());
jest.mock(
    '@salesforce/apex/MRG_KeepRecordRules_CTRL.saveKeepRecordRules',
    () => ({ default: (...args) => mockSave(...args) }),
    { virtual: true }
);

function flush() {
    return Promise.resolve();
}
function byLabel(el, tag, label) {
    return Array.from(el.shadowRoot.querySelectorAll(tag)).find(e => e.label === label);
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
        byLabel(el, 'lightning-combobox', 'Object').dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
        await flush();
        await flush();
        await flush();
        return el;
    }

    it('strips UI-only keys from the payload sent to Apex on save', async () => {
        const el = await renderForAccount();
        byLabel(el, 'lightning-button', 'Save').dispatchEvent(new CustomEvent('click'));
        await flush();

        expect(mockSave).toHaveBeenCalled();
        const payload = JSON.parse(mockSave.mock.calls[0][0].jsonData);
        expect(payload).toHaveLength(1);
        expect(Object.keys(payload[0]).sort()).toEqual(['conditions', 'filterLogic', 'id', 'label', 'objectName', 'order']);
        expect(Object.keys(payload[0].conditions[0]).sort()).toEqual(['fieldName', 'operator', 'value']);
    });

    it('adds a rule for the selected object', async () => {
        const el = await renderForAccount();
        byLabel(el, 'lightning-button', 'Add Rule').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(Array.from(el.shadowRoot.querySelectorAll('lightning-input')).some(i => i.label === 'Rule Label')).toBe(true);
    });
});
