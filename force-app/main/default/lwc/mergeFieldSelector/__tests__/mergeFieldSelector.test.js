import { createElement } from 'lwc';
import MergeFieldSelector from 'c/mergeFieldSelector';

const OPTIONS = [
    { label: 'Email', value: 'Email' },
    { label: 'Mailing Street', value: 'MailingStreet' },
    { label: 'Phone', value: 'Phone' }
];

function flush() {
    return Promise.resolve();
}
function input(el) {
    return el.shadowRoot.querySelector('input');
}
function optionText(el) {
    return Array.from(el.shadowRoot.querySelectorAll('.field-option')).map(o => o.textContent.trim());
}
function optionEl(el, value) {
    return Array.from(el.shadowRoot.querySelectorAll('.field-option')).find(o => o.dataset.value === value);
}

describe('c-merge-field-selector', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    async function render() {
        const el = createElement('c-merge-field-selector', { is: MergeFieldSelector });
        el.options = OPTIONS;
        document.body.appendChild(el);
        await flush();
        return el;
    }

    async function type(el, text) {
        const field = input(el);
        field.value = text;
        field.dispatchEvent(new CustomEvent('input'));
        await flush();
    }

    it('shows no results until at least 3 characters are typed', async () => {
        const el = await render();
        input(el).dispatchEvent(new CustomEvent('focus'));
        await flush();
        expect(optionText(el)).toEqual([]); // focus alone shows nothing

        await type(el, 'ph');
        expect(optionText(el)).toEqual([]); // 2 chars -> still nothing

        await type(el, 'pho');
        expect(optionText(el)).toEqual(['Phone (Phone)']); // 3 chars -> results
    });

    it('filters by label (contains)', async () => {
        const el = await render();
        await type(el, 'street');
        expect(optionText(el)).toEqual(['Mailing Street (MailingStreet)']);
    });

    it('filters by API name (contains)', async () => {
        const el = await render();
        await type(el, 'mailingstreet');
        expect(optionText(el)).toEqual(['Mailing Street (MailingStreet)']);
    });

    it('selecting an option dispatches change with the API value', async () => {
        const el = await render();
        const handler = jest.fn();
        el.addEventListener('change', handler);
        await type(el, 'pho');
        optionEl(el, 'Phone').dispatchEvent(new CustomEvent('mousedown'));
        expect(handler.mock.calls[0][0].detail.value).toBe('Phone');
    });
});
