import { createElement } from 'lwc';
import AutoMergeAccountsRules from 'c/autoMergeAccountsRules';

jest.mock(
    'lightning/empApi',
    () => ({ subscribe: jest.fn(() => Promise.resolve({})), onError: jest.fn() }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_AutoMergeAccounts_CTRL.getObjectFields',
    () => ({ default: jest.fn(() => Promise.resolve([{ label: 'Email', name: 'Email', type: 'STRING' }])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_AutoMergeAccounts_CTRL.getRules',
    () => ({
        default: jest.fn(() => Promise.resolve([
            { id: 'a1', label: 'AMA1', objectName: 'Contact', autoMerge: true, filterLogic: '1', conditions: [{ fieldName: 'Email', operator: 'equals', value: 'x', aggregator: 'all' }] }
        ]))
    }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_AutoMergeAccounts_CTRL.getOperators',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_AutoMergeAccounts_CTRL.getAggregators',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
const mockSave = jest.fn(() => Promise.resolve());
jest.mock(
    '@salesforce/apex/MRG_AutoMergeAccounts_CTRL.saveRules',
    () => ({ default: (...args) => mockSave(...args) }),
    { virtual: true }
);

function flush() {
    return Promise.resolve();
}
function byLabel(el, tag, label) {
    return Array.from(el.shadowRoot.querySelectorAll(tag)).find(e => e.label === label);
}

describe('c-auto-merge-accounts-rules', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    async function renderForContact() {
        const el = createElement('c-auto-merge-accounts-rules', { is: AutoMergeAccountsRules });
        document.body.appendChild(el);
        byLabel(el, 'lightning-combobox', 'Object').dispatchEvent(new CustomEvent('change', { detail: { value: 'Contact' } }));
        await flush();
        await flush();
        await flush();
        return el;
    }

    it('strips UI-only keys (incl. condition aggregator/input metadata) on save', async () => {
        const el = await renderForContact();
        byLabel(el, 'lightning-button', 'Save').dispatchEvent(new CustomEvent('click'));
        await flush();

        expect(mockSave).toHaveBeenCalled();
        const payload = JSON.parse(mockSave.mock.calls[0][0].jsonData);
        expect(payload).toHaveLength(1);
        expect(Object.keys(payload[0]).sort()).toEqual(['autoMerge', 'conditions', 'filterLogic', 'id', 'label', 'objectName']);
        expect(Object.keys(payload[0].conditions[0]).sort()).toEqual(['aggregator', 'fieldName', 'operator', 'value']);
    });

    it('adds a rule for the selected object', async () => {
        const el = await renderForContact();
        byLabel(el, 'lightning-button', 'Add Rule').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(Array.from(el.shadowRoot.querySelectorAll('lightning-input')).some(i => i.label === 'Rule Label')).toBe(true);
    });
});
