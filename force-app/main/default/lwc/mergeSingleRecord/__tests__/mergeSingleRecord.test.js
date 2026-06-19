import { createElement } from 'lwc';
import MergeSingleRecord from 'c/mergeSingleRecord';
import getReadableObjectFields from '@salesforce/apex/MRG_MergeSettings_CTRL.getReadableObjectFields';

jest.mock(
    '@salesforce/apex/MRG_MergeSettings_CTRL.getReadableObjectFields',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

function flush() {
    return Promise.resolve();
}
function ruleCombobox(el) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-combobox'))
        .find(c => Array.isArray(c.options) && c.options.some(o => o.value === 'Oldest'));
}
function hasButton(el, label) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-button')).some(b => b.label === label);
}
function hasInput(el, label) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-input')).some(i => i.label === label);
}
function hasInputContaining(el, text) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-input')).some(i => (i.label || '').includes(text));
}
function tabLabels(el) {
    return Array.from(el.shadowRoot.querySelectorAll('.slds-tabs_default__link')).map(a => a.textContent.trim());
}
function advancedToggle(el) {
    return el.shadowRoot.querySelector('.advanced-toggle');
}

async function renderWithRule(rule) {
    const el = createElement('c-merge-single-record', { is: MergeSingleRecord });
    el.usedFields = [];
    // name includes TEMP -> edit mode; type 'p' -> preserve, so the rule config sections can show
    el.record = { name: 'TEMPx', type: 'p', rule, objectName: 'Contact', fieldName: 'Email', conditions: [], filterLogic: '', tieBreakDirection: 'DESC' };
    document.body.appendChild(el);
    await flush();
    return el;
}

describe('c-merge-single-record', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('reveals the Complex condition builder when the rule is Complex', async () => {
        const el = await renderWithRule('Complex');
        expect(hasButton(el, 'Add Condition')).toBe(true);
    });

    it('reveals the substring input when the rule is Contains', async () => {
        const el = await renderWithRule('Contains');
        expect(hasInput(el, 'Contains Value')).toBe(true);
    });

    it('reveals the Apex Class input when the rule is Apex Defined', async () => {
        const el = await renderWithRule('Apex Defined');
        expect(hasInput(el, 'Apex Class')).toBe(true);
    });

    it('shows no rule config for a simple rule', async () => {
        const el = await renderWithRule('Newest');
        expect(hasButton(el, 'Add Condition')).toBe(false);
        expect(hasInput(el, 'Contains Value')).toBe(false);
        expect(hasInput(el, 'Apex Class')).toBe(false);
    });

    it('offers Combine Values only when the selected field is a multipicklist', async () => {
        const el = createElement('c-merge-single-record', { is: MergeSingleRecord });
        el.usedFields = [];
        el.record = { name: 'TEMPx', type: 'p', rule: 'Newest', objectName: 'Contact', fieldName: 'Tags', conditions: [] };
        document.body.appendChild(el);
        getReadableObjectFields.emit([{ label: 'Tags', name: 'Tags', type: 'MULTIPICKLIST' }]);
        await flush();
        await flush();
        expect(ruleCombobox(el).options.some(o => o.value === 'Combine')).toBe(true);
    });

    it('hides Combine Values for a non-multipicklist field', async () => {
        const el = createElement('c-merge-single-record', { is: MergeSingleRecord });
        el.usedFields = [];
        el.record = { name: 'TEMPx', type: 'p', rule: 'Newest', objectName: 'Contact', fieldName: 'Email', conditions: [] };
        document.body.appendChild(el);
        getReadableObjectFields.emit([{ label: 'Email', name: 'Email', type: 'EMAIL' }]);
        await flush();
        await flush();
        expect(ruleCombobox(el).options.some(o => o.value === 'Combine')).toBe(false);
    });

    it('shows the Tie-Break Rule picker in the Complex section', async () => {
        const el = await renderWithRule('Complex');
        const labels = Array.from(el.shadowRoot.querySelectorAll('lightning-combobox')).map(c => c.label);
        expect(labels).toContain('Tie-Break Rule (primary)');
    });

    it('auto-opens Advanced with Rule Definition, Tie-Break and Fallback tabs for Complex', async () => {
        const el = await renderWithRule('Complex');
        expect(tabLabels(el)).toEqual(['Rule Definition', 'Tie-Break', 'Fallback Field']);
    });

    it('shows Related Field + Fallback tabs for the Related Field rule', async () => {
        const el = await renderWithRule('Related Field');
        expect(tabLabels(el)).toEqual(['Related Field', 'Fallback Field']);
    });

    it('shows Contains Value + Fallback tabs for the Contains rule', async () => {
        const el = await renderWithRule('Contains');
        expect(tabLabels(el)).toEqual(['Contains Value', 'Fallback Field']);
    });

    it('keeps Advanced collapsed for a simple rule and shows only Fallback when expanded', async () => {
        const el = await renderWithRule('Newest');
        expect(tabLabels(el)).toEqual([]); // collapsed -> tabs not rendered
        advancedToggle(el).dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(tabLabels(el)).toEqual(['Fallback Field']);
    });

    it('keeps Filter Logic collapsed by default (Complex with no filter logic)', async () => {
        const el = await renderWithRule('Complex');
        expect(hasButton(el, 'Add Condition')).toBe(true);
        expect(hasInputContaining(el, 'Filter Logic')).toBe(false);
    });

    it('expands Filter Logic when it already has a value', async () => {
        const el = createElement('c-merge-single-record', { is: MergeSingleRecord });
        el.usedFields = [];
        el.record = { name: 'TEMPx', type: 'p', rule: 'Complex', objectName: 'Contact', fieldName: 'Email', conditions: [], filterLogic: '1 AND 2', tieBreakDirection: 'DESC' };
        document.body.appendChild(el);
        await flush();
        expect(hasInputContaining(el, 'Filter Logic')).toBe(true);
    });

    it('dispatches a save notify when Save is clicked', async () => {
        const el = await renderWithRule('Newest');
        const handler = jest.fn();
        el.addEventListener('notify', handler);
        Array.from(el.shadowRoot.querySelectorAll('lightning-button')).find(b => b.label === 'Save').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(handler).toHaveBeenCalled();
        expect(handler.mock.calls[0][0].detail.actionType).toBe('save');
    });
});
