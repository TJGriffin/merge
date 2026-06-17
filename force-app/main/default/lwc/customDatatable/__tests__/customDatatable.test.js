import { createElement } from 'lwc';
import CustomDatatable from 'c/customDatatable';

describe('c-custom-datatable', () => {
    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('mounts as a lightning-datatable extension without error', () => {
        const element = createElement('c-custom-datatable', {
            is: CustomDatatable
        });
        document.body.appendChild(element);
        const mounted = document.body.querySelector('c-custom-datatable');
        expect(mounted).not.toBeNull();
        expect(mounted.shadowRoot).toBeTruthy();
    });
});