import { createElement } from 'lwc';
import Pager from 'c/pager';

function flush() {
    return Promise.resolve();
}
function pageButtons(el) {
    return Array.from(el.shadowRoot.querySelectorAll('button.page-index'));
}

describe('c-pager', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    async function render(totalPages, currentPage) {
        const el = createElement('c-pager', { is: Pager });
        el.totalPages = totalPages;
        el.currentPage = currentPage;
        document.body.appendChild(el);
        await flush();
        return el;
    }

    it('hides the pager when there is a single page', async () => {
        const el = await render(1, 1);
        expect(pageButtons(el).length).toBe(0);
    });

    it('renders a button per page and disables the current page', async () => {
        const el = await render(3, 1);
        const pages = pageButtons(el);
        expect(pages.length).toBe(3);
        expect(pages.find(b => Number(b.value) === 1).disabled).toBe(true);
    });

    it('fires a page event with the selected page number', async () => {
        const el = await render(3, 1);
        const handler = jest.fn();
        el.addEventListener('page', handler);
        pageButtons(el).find(b => Number(b.value) === 2).dispatchEvent(new CustomEvent('click'));
        expect(handler.mock.calls[0][0].detail).toBe(2);
    });

    it('Next advances to the following page', async () => {
        const el = await render(3, 1);
        const handler = jest.fn();
        el.addEventListener('page', handler);
        // only Next renders on the first page
        el.shadowRoot.querySelector('lightning-button-icon').dispatchEvent(new CustomEvent('click'));
        expect(handler.mock.calls[0][0].detail).toBe(2);
    });
});
