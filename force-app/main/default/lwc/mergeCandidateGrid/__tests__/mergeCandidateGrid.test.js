import { createElement } from 'lwc';
import MergeCandidateGrid from 'c/mergeCandidateGrid';

const KEEP_GROUPS = [
    {
        keepId: '003A', keepName: 'Acme', objectType: 'Contact',
        pairs: [{ id: 'mc1', mergeId: '003B', mergeName: 'Acme 2', confidenceScore: 90 }]
    },
    {
        keepId: '003C', keepName: 'Globex', objectType: 'Contact',
        pairs: [{ id: 'mc2', mergeId: '003D', mergeName: 'Globex Inc', confidenceScore: 80 }]
    }
];
const FIELD_OPTIONS = {
    leadFields: [{ name: 'Id', label: 'Record ID', type: 'id' }],
    trailFields: [
        { name: 'CreatedDate', label: 'Created Date', type: 'datetime' },
        { name: 'LastModifiedDate', label: 'Last Modified Date', type: 'datetime' }
    ],
    fields: [
        { name: 'Email', label: 'Email', type: 'email', displayLabel: 'Email (Email)', selected: true },
        { name: 'Phone', label: 'Phone', type: 'phone', displayLabel: 'Phone (Phone)', selected: false }
    ]
};
const GRID_ROWS = {
    columns: [
        { name: 'Id', label: 'Record ID', type: 'id' },
        { name: 'Email', label: 'Email', type: 'email' }
    ],
    groups: [
        {
            keepId: '003A',
            rows: [
                { rowType: 'keep', recordId: '003A', candidateId: null, cells: [{ name: 'Id', value: '003A' }, { name: 'Email', value: 'a@x.com' }] },
                { rowType: 'duplicate', recordId: '003B', candidateId: 'mc1', cells: [{ name: 'Id', value: '003B' }, { name: 'Email', value: 'b@x.com' }] },
                { rowType: 'result', recordId: '003A', candidateId: null, cells: [{ name: 'Id', value: '003A' }, { name: 'Email', value: 'a@x.com' }] }
            ]
        },
        {
            keepId: '003C',
            rows: [
                { rowType: 'keep', recordId: '003C', candidateId: null, cells: [{ name: 'Id', value: '003C' }, { name: 'Email', value: 'c@x.com' }] },
                { rowType: 'duplicate', recordId: '003D', candidateId: 'mc2', cells: [{ name: 'Id', value: '003D' }, { name: 'Email', value: 'd@x.com' }] },
                { rowType: 'result', recordId: '003C', candidateId: null, cells: [{ name: 'Id', value: '003C' }, { name: 'Email', value: 'c@x.com' }] }
            ]
        }
    ]
};

jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.getKeepGroups',
    () => ({ default: jest.fn(() => Promise.resolve(KEEP_GROUPS)) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.getGridRows',
    () => ({ default: jest.fn(() => Promise.resolve(GRID_ROWS)) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.getGridFieldOptions',
    () => ({ default: jest.fn(() => Promise.resolve(FIELD_OPTIONS)) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.getCount',
    () => ({ default: jest.fn(() => Promise.resolve(1)) }),
    { virtual: true }
);
const mockSaveConfig = jest.fn(() => Promise.resolve());
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.saveGridFieldConfig',
    () => ({ default: (...args) => mockSaveConfig(...args) }),
    { virtual: true }
);
const mockMergeRecords = jest.fn(() => Promise.resolve('1 record(s) merged'));
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.mergeRecords',
    () => ({ default: (...args) => mockMergeRecords(...args) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.removeRecords',
    () => ({ default: jest.fn(() => Promise.resolve('removed')) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.mergeAccountsBulk',
    () => ({ default: jest.fn(() => Promise.resolve('merged')) }),
    { virtual: true }
);
const mockRunOverFilter = jest.fn(() => Promise.resolve('707000000000000AAA'));
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.runActionOverFilter',
    () => ({ default: (...args) => mockRunOverFilter(...args) }),
    { virtual: true }
);
const mockSetOverride = jest.fn(() => Promise.resolve('Keep value overridden'));
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.setKeepFieldOverride',
    () => ({ default: (...args) => mockSetOverride(...args) }),
    { virtual: true }
);

function flush() {
    return new Promise(resolve => setTimeout(resolve, 0));
}
function buttonByLabel(el, label) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-button')).find(b => b.label === label);
}
function nativeButtonByText(el, text) {
    return Array.from(el.shadowRoot.querySelectorAll('button.slds-button')).find(b => b.textContent.trim() === text);
}
function gearButton(el) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-button-icon')).find(b => b.iconName === 'utility:settings');
}
function gridSearch(el) {
    return el.shadowRoot.querySelector('.grid-search lightning-input');
}
async function searchFor(el, term) {
    gridSearch(el).dispatchEvent(new CustomEvent('change', { detail: { value: term } }));
    await flush();
}
function groupHeaders(el) {
    return Array.from(el.shadowRoot.querySelectorAll('.slds-theme_shade strong')).map(n => n.textContent.trim());
}

async function render() {
    const el = createElement('c-merge-candidate-grid', { is: MergeCandidateGrid });
    el.objectType = 'Contact';
    el.filter = { objectType: 'Contact', ruleName: 'test', statuses: ['New'] };
    document.body.appendChild(el);
    await flush();
    await flush();
    return el;
}

describe('c-merge-candidate-grid', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders a group with keep/duplicate/result rows and a column per field', async () => {
        const el = await render();
        // each group renders its own table: Row + one column per field
        const tables = el.shadowRoot.querySelectorAll('table.grid-table');
        expect(tables.length).toBe(KEEP_GROUPS.length);
        const headers = tables[0].querySelectorAll('thead th');
        expect(headers.length).toBe(GRID_ROWS.columns.length + 1);
        const checkboxes = Array.from(el.shadowRoot.querySelectorAll('lightning-input')).filter(i => i.type === 'checkbox');
        expect(checkboxes.length).toBe(KEEP_GROUPS.length); // one selectable duplicate row per group
        const preview = Array.from(el.shadowRoot.querySelectorAll('lightning-button-icon')).find(b => b.iconName === 'utility:preview');
        expect(preview).toBeTruthy();
    });

    it('select page then Merge calls the bulk action with the page candidate ids', async () => {
        const el = await render();
        expect(nativeButtonByText(el, 'Merge').disabled).toBe(true);
        nativeButtonByText(el, 'Select page').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(nativeButtonByText(el, 'Merge').disabled).toBe(false);
        nativeButtonByText(el, 'Merge').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(mockMergeRecords).toHaveBeenCalledWith({ recordIds: ['mc1', 'mc2'] });
    });

    it('select all pages then Merge runs the background batch over the filter', async () => {
        const el = await render();
        nativeButtonByText(el, 'Select all pages').dispatchEvent(new CustomEvent('click'));
        await flush();
        nativeButtonByText(el, 'Merge').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(mockMergeRecords).not.toHaveBeenCalled();
        expect(mockRunOverFilter).toHaveBeenCalled();
        const args = mockRunOverFilter.mock.calls[0][0];
        expect(args.action).toBe('merge');
        expect(args.filter.objectType).toBe('Contact');
    });

    it('opens the preview modal from a duplicate row', async () => {
        const el = await render();
        const preview = Array.from(el.shadowRoot.querySelectorAll('lightning-button-icon')).find(b => b.iconName === 'utility:preview');
        preview.dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(el.shadowRoot.querySelector('c-merge-preview')).toBeTruthy();
    });

    it('header Preview opens the modal for the current selection', async () => {
        const el = await render();
        expect(nativeButtonByText(el, 'Preview').disabled).toBe(true);
        nativeButtonByText(el, 'Select page').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(nativeButtonByText(el, 'Preview').disabled).toBe(false);
        nativeButtonByText(el, 'Preview').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(el.shadowRoot.querySelector('c-merge-preview')).toBeTruthy();
    });

    it('batches field toggles, saves on Save, and closes the panel', async () => {
        const el = await render();
        gearButton(el).dispatchEvent(new CustomEvent('click'));
        await flush();
        const phone = Array.from(el.shadowRoot.querySelectorAll('.grid-field-panel lightning-input')).find(i => i.dataset.field === 'Phone');
        phone.checked = true;
        phone.dispatchEvent(new CustomEvent('change'));
        await flush();
        expect(mockSaveConfig).not.toHaveBeenCalled();
        buttonByLabel(el, 'Save').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(mockSaveConfig).toHaveBeenCalledWith({ objectType: 'Contact', fields: ['Email', 'Phone'] });
        expect(el.shadowRoot.querySelector('.grid-field-panel')).toBeNull();
    });

    it('overrides the merge result: pencil opens a combobox, selection persists to the group candidates', async () => {
        const el = await render();
        // Email differs across keep/duplicate, so the result Email cell is editable
        const pencil = Array.from(el.shadowRoot.querySelectorAll('lightning-button-icon')).find(b => b.iconName === 'utility:edit');
        expect(pencil).toBeTruthy();
        pencil.dispatchEvent(new CustomEvent('click'));
        await flush();
        const combo = el.shadowRoot.querySelector('select[data-field="Email"]');
        expect(combo).toBeTruthy();
        // both distinct non-null values across the group are offered
        const optionValues = Array.from(combo.querySelectorAll('option')).map(o => o.value).sort();
        expect(optionValues).toEqual(['a@x.com', 'b@x.com']);
        combo.value = 'b@x.com';
        combo.dispatchEvent(new CustomEvent('change'));
        await flush();
        expect(mockSetOverride).toHaveBeenCalledWith({ candidateIds: ['mc1'], field: 'Email', value: 'b@x.com' });
    });

    it('filters the field list by label or api name', async () => {
        const el = await render();
        gearButton(el).dispatchEvent(new CustomEvent('click'));
        await flush();
        // scoped to the field panel: the toolbar has its own candidate search input
        const search = Array.from(el.shadowRoot.querySelectorAll('.grid-field-panel lightning-input')).find(i => i.type === 'search');
        search.dispatchEvent(new CustomEvent('change', { detail: { value: 'phone' } }));
        await flush();
        const checks = Array.from(el.shadowRoot.querySelectorAll('.grid-field-panel lightning-input')).filter(i => i.type === 'checkbox');
        expect(checks.length).toBe(1);
        expect(checks[0].dataset.field).toBe('Phone');
    });
    // ---- grid search over the loaded merge candidates ----
    it('filters groups by keep name', async () => {
        const el = await render();
        expect(groupHeaders(el).length).toBe(2);
        await searchFor(el, 'globex');
        const headers = groupHeaders(el);
        expect(headers.length).toBe(1);
        expect(headers[0]).toContain('Globex');
    });

    it('filters groups by duplicate (merge) name', async () => {
        const el = await render();
        await searchFor(el, 'Acme 2');
        const headers = groupHeaders(el);
        expect(headers.length).toBe(1);
        expect(headers[0]).toContain('Acme');
    });

    it('matches on record ids as well as names', async () => {
        const el = await render();
        await searchFor(el, '003D');
        const headers = groupHeaders(el);
        expect(headers.length).toBe(1);
        expect(headers[0]).toContain('Globex');
    });

    it('search is case-insensitive and ignores surrounding whitespace', async () => {
        const el = await render();
        await searchFor(el, '  GLOBEX  ');
        expect(groupHeaders(el).length).toBe(1);
    });

    it('shows a no-results message and restores all groups when the search is cleared', async () => {
        const el = await render();
        await searchFor(el, 'nothingmatchesthis');
        expect(groupHeaders(el).length).toBe(0);
        expect(el.shadowRoot.textContent).toContain('No merge candidates match');

        await searchFor(el, '');
        expect(groupHeaders(el).length).toBe(2);
    });

    it('only selects candidates from the filtered view when selecting the page', async () => {
        const el = await render();
        await searchFor(el, 'globex');
        nativeButtonByText(el, 'Select page').dispatchEvent(new CustomEvent('click'));
        await flush();
        // mc1 (Acme) is filtered out, so only the Globex candidate is selected
        expect(el.shadowRoot.textContent).toContain('1 selected');
        nativeButtonByText(el, 'Merge').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(mockMergeRecords).toHaveBeenCalledWith({ recordIds: ['mc2'] });
    });

    it('pages over the filtered set and resets to page 1 when the term changes', async () => {
        const el = await render();
        // one group per page: page 2 shows Globex
        const pageSize = el.shadowRoot.querySelector('lightning-combobox');
        pageSize.dispatchEvent(new CustomEvent('change', { detail: { value: '5' } }));
        await flush();
        // narrow to a single group while on a later page -> must snap back to a valid page
        await searchFor(el, 'globex');
        expect(groupHeaders(el).length).toBe(1);
        expect(groupHeaders(el)[0]).toContain('Globex');
        // the pager is gone because the filtered set fits on one page
        expect(el.shadowRoot.querySelector('c-pager')).toBeNull();
    });
});
