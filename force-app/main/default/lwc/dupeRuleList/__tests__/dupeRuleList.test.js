import { createElement } from 'lwc';
import DupeRuleList from 'c/dupeRuleList';
import getDuplicateRules from '@salesforce/apex/MRG_DupeSettings_CTRL.getDuplicateRuleSettings';

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
    '@salesforce/apex/MRG_DupeSettings_CTRL.getDuplicateRuleSettings',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DupeSettings_CTRL.saveDuplicateRuleSettings',
    () => ({ default: jest.fn(() => Promise.resolve()) }),
    { virtual: true }
);

const ROWS = [
    { name: 'AcctDupe', ruleName: 'AcctDupe', objectType: 'Account', autoMerge: false },
    { name: 'ContactDupe', ruleName: 'ContactDupe', objectType: 'Contact', autoMerge: true }
];

function flush() {
    return Promise.resolve();
}
function rowEls(el) {
    return el.shadowRoot.querySelectorAll('c-dupe-rule-single-record');
}
function addButton(el) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-button')).find(b => b.label === 'Add New Duplicate Rule Setting');
}

describe('c-dupe-rule-list', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    async function render() {
        const el = createElement('c-dupe-rule-list', { is: DupeRuleList });
        document.body.appendChild(el);
        getDuplicateRules.emit(ROWS);
        await flush();
        await flush();
        return el;
    }

    it('renders one row per duplicate rule setting', async () => {
        const el = await render();
        expect(rowEls(el).length).toBe(2);
    });

    it('cancelling an added rule removes the empty placeholder row', async () => {
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
