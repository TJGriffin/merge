import { createElement } from 'lwc';
import MergeSingleRecord from 'c/mergeSingleRecord';

function flush() {
    return Promise.resolve();
}
function hasButton(el, label) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-button')).some(b => b.label === label);
}
function hasInput(el, label) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-input')).some(i => i.label === label);
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
