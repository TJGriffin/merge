import { createElement } from 'lwc';
import PreviewFields from 'c/previewFields';
import getAllPreviewFields from '@salesforce/apex/MRG_MergeSettings_CTRL.getAllPreviewFields';

// lightning/empApi has no built-in jest stub; provide a virtual mock
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

// the @wire-d apex method as a test wire adapter we can emit on
jest.mock(
    '@salesforce/apex/MRG_MergeSettings_CTRL.getAllPreviewFields',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_MergeSettings_CTRL.savePreviewFieldsSettings',
    () => ({ default: jest.fn(() => Promise.resolve()) }),
    { virtual: true }
);
const mockSuppress = jest.fn(() => Promise.resolve('job-id'));
jest.mock(
    '@salesforce/apex/MRG_MergeSettings_CTRL.suppressPreviewFields',
    () => ({ default: (...args) => mockSuppress(...args) }),
    { virtual: true }
);

const ROWS = [
    { id: 'a', label: 'Phone', name: 'PhoneContact', objectName: 'Contact', fieldName: 'Phone', hidden: true },
    { id: 'b', label: 'Fax', name: 'FaxContact', objectName: 'Contact', fieldName: 'Fax', hidden: true }
];

function flush() {
    return Promise.resolve();
}
function rowEls(el) {
    return el.shadowRoot.querySelectorAll('c-preview-field-single-record');
}
function addButton(el) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-button')).find(b => b.label === 'Hide New Field');
}

describe('c-preview-fields', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    async function render() {
        const el = createElement('c-preview-fields', { is: PreviewFields });
        document.body.appendChild(el);
        getAllPreviewFields.emit(ROWS);
        await flush();
        await flush();
        return el;
    }

    it('renders one row per preview field setting', async () => {
        const el = await render();
        expect(rowEls(el).length).toBe(2);
    });

    it('cancelling an added field removes the empty placeholder row', async () => {
        const el = await render();
        addButton(el).dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(rowEls(el).length).toBe(3); // placeholder added

        // the child fires notify with a 'cancel' action
        rowEls(el)[2].dispatchEvent(new CustomEvent('notify', { detail: { actionType: 'cancel' } }));
        await flush();

        // regression: the placeholder used to linger, leaving an un-removable empty row
        expect(rowEls(el).length).toBe(2);
    });

    it('adding twice does not stack two placeholder rows', async () => {
        const el = await render();
        addButton(el).dispatchEvent(new CustomEvent('click'));
        await flush();
        addButton(el).dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(rowEls(el).length).toBe(3); // a single placeholder, not two
    });

    // ---- bulk "suppress a list of fields" modal ----
    const opener = el => Array.from(el.shadowRoot.querySelectorAll('lightning-button')).find(b => b.label === 'Suppress a List of Fields');
    // base-component attributes aren't reflected to the DOM in the stubs, so select by label/type
    const combobox = el => Array.from(el.shadowRoot.querySelectorAll('lightning-combobox')).find(c => c.label === 'Object');
    const textarea = el => el.shadowRoot.querySelector('lightning-textarea');
    const submit = el => Array.from(el.shadowRoot.querySelectorAll('button')).find(b => b.textContent.trim() === 'Suppress Fields');

    it('requires an object and field list before the suppress submit is enabled', async () => {
        const el = await render();
        opener(el).dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(combobox(el)).not.toBeNull(); // modal open
        expect(submit(el).disabled).toBe(true); // nothing entered

        combobox(el).dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
        await flush();
        expect(submit(el).disabled).toBe(true); // object only, still no fields

        const ta = textarea(el);
        ta.value = 'Phone, Fax';
        ta.dispatchEvent(new CustomEvent('change'));
        await flush();
        expect(submit(el).disabled).toBe(false); // both set
    });

    it('submits the comma-delimited list to suppressPreviewFields', async () => {
        const el = await render();
        opener(el).dispatchEvent(new CustomEvent('click'));
        await flush();
        combobox(el).dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
        const ta = textarea(el);
        ta.value = 'Phone, Fax';
        ta.dispatchEvent(new CustomEvent('change'));
        await flush();

        submit(el).dispatchEvent(new CustomEvent('click'));
        await flush();

        expect(mockSuppress).toHaveBeenCalledWith({ objectType: 'Account', fieldNames: 'Phone, Fax' });
    });
});
