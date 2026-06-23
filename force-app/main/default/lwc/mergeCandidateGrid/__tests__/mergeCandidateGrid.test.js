import { createElement } from 'lwc';
import MergeCandidateGrid from 'c/mergeCandidateGrid';

const FIELD_OPTIONS = {
    leadFields: [{ name: 'Id', label: 'Record ID', type: 'id' }],
    optionalFields: [{ name: 'Phone', label: 'Phone', type: 'phone' }],
    trailFields: [
        { name: 'CreatedDate', label: 'Created Date', type: 'datetime' },
        { name: 'LastModifiedDate', label: 'Last Modified Date', type: 'datetime' }
    ]
};
const GRID_DATA = {
    columns: [
        { name: 'Id', label: 'Record ID', type: 'id' },
        { name: 'Email', label: 'Email', type: 'email' }
    ],
    groups: [
        {
            keepId: '003A', keepName: 'Acme', objectType: 'Contact',
            rows: [
                { rowType: 'keep', recordId: '003A', candidateId: null, selectable: false,
                  cells: [{ name: 'Id', value: '003A' }, { name: 'Email', value: 'a@x.com' }] },
                { rowType: 'duplicate', recordId: '003B', candidateId: 'mc1', selectable: true,
                  cells: [{ name: 'Id', value: '003B' }, { name: 'Email', value: 'b@x.com' }] },
                { rowType: 'result', recordId: '003A', candidateId: null, selectable: false,
                  cells: [{ name: 'Id', value: '003A' }, { name: 'Email', value: 'a@x.com' }] }
            ]
        }
    ]
};

jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.getGridFieldOptions',
    () => ({ default: jest.fn(() => Promise.resolve(FIELD_OPTIONS)) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.getGridData',
    () => ({ default: jest.fn(() => Promise.resolve(GRID_DATA)) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.getCount',
    () => ({ default: jest.fn(() => Promise.resolve(1)) }),
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

function flush() {
    return new Promise(resolve => setTimeout(resolve, 0));
}
function buttonByLabel(el, label) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-button')).find(b => b.label === label);
}
async function render() {
    const el = createElement('c-merge-candidate-grid', { is: MergeCandidateGrid });
    el.objectType = 'Contact';
    el.filter = { objectType: 'Contact', ruleName: 'test', statuses: ['New'] };
    document.body.appendChild(el);
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

    it('renders a column per field and a row per keep/duplicate/result', async () => {
        const el = await render();
        const headers = el.shadowRoot.querySelectorAll('thead th');
        // one "Row" header + one per column
        expect(headers.length).toBe(GRID_DATA.columns.length + 1);
        // a checkbox is rendered only for the selectable duplicate row
        const checkboxes = Array.from(el.shadowRoot.querySelectorAll('lightning-input'))
            .filter(i => i.type === 'checkbox');
        expect(checkboxes.length).toBe(1);
    });

    it('enables actions on selection and merges the selected candidate', async () => {
        const el = await render();
        expect(buttonByLabel(el, 'Merge').disabled).toBe(true);

        const checkbox = Array.from(el.shadowRoot.querySelectorAll('lightning-input'))
            .find(i => i.dataset.candidate === 'mc1');
        checkbox.checked = true;
        checkbox.dispatchEvent(new CustomEvent('change'));
        await flush();

        expect(buttonByLabel(el, 'Merge').disabled).toBe(false);
        buttonByLabel(el, 'Merge').dispatchEvent(new CustomEvent('click'));
        await flush();
        expect(mockMergeRecords).toHaveBeenCalledWith({ recordIds: ['mc1'] });
    });

    it('reveals optional field checkboxes when the field panel is toggled', async () => {
        const el = await render();
        expect(el.shadowRoot.querySelector('.grid-field-panel')).toBeNull();
        buttonByLabel(el, 'Configure Fields').dispatchEvent(new CustomEvent('click'));
        await flush();
        const panel = el.shadowRoot.querySelector('.grid-field-panel');
        expect(panel).toBeTruthy();
        const optional = Array.from(panel.querySelectorAll('lightning-input'))
            .find(i => i.dataset.field === 'Phone');
        expect(optional).toBeTruthy();
    });
});
