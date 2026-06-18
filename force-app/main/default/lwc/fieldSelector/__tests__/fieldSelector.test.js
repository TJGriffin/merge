import { createElement } from 'lwc';
import FieldSelector from 'c/fieldSelector';

const OPTIONS = [
    { label: 'Email', value: 'Email' },
    { label: 'Mailing Street', value: 'MailingStreet' },
    { label: 'Phone', value: 'Phone' }
];

function flush() {
    return Promise.resolve();
}
function input(el) {
    return el.shadowRoot.querySelector('lightning-input');
}
function optionText(el) {
    return Array.from(el.shadowRoot.querySelectorAll('.field-option')).map(o => o.textContent.trim());
}
function optionEl(el, value) {
    return Array.from(el.shadowRoot.querySelectorAll('.field-option')).find(o => o.dataset.value === value);
}

describe('c-field-selector', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    async function render() {
        const el = createElement('c-field-selector', { is: FieldSelector });
        el.options = OPTIONS;
        document.body.appendChild(el);
        await flush();
        return el;
    }

    it('lists options as "label (api name)" when focused', async () => {
        const el = await render();
        input(el).dispatchEvent(new CustomEvent('focus'));
        await flush();
        expect(optionText(el)).toEqual(
            expect.arrayContaining(['Email (Email)', 'Mailing Street (MailingStreet)', 'Phone (Phone)'])
        );
    });

    it('filters by label', async () => {
        const el = await render();
        input(el).dispatchEvent(new CustomEvent('focus'));
        const field = input(el);
        field.value = 'mailing';
        field.dispatchEvent(new CustomEvent('input'));
        await flush();
        expect(optionText(el)).toEqual(['Mailing Street (MailingStreet)']);
    });

    it('filters by API name', async () => {
        const el = await render();
        input(el).dispatchEvent(new CustomEvent('focus'));
        const field = input(el);
        field.value = 'MailingStreet';
        field.dispatchEvent(new CustomEvent('input'));
        await flush();
        expect(optionText(el)).toEqual(['Mailing Street (MailingStreet)']);
    });

    it('selecting an option dispatches change with the API value', async () => {
        const el = await render();
        const handler = jest.fn();
        el.addEventListener('change', handler);
        input(el).dispatchEvent(new CustomEvent('focus'));
        await flush();
        optionEl(el, 'Phone').dispatchEvent(new CustomEvent('mousedown'));
        expect(handler.mock.calls[0][0].detail.value).toBe('Phone');
    });
});
