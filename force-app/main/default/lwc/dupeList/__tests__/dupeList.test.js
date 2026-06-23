import { createElement } from 'lwc';
import DupeList from 'c/dupeList';
import getKeepGroups from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getKeepGroups';

jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.getKeepGroups',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.getRules',
    () => ({ default: jest.fn(() => Promise.resolve([])) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.getCount',
    () => ({ default: jest.fn(() => Promise.resolve(1)) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.getStatusOptions',
    () => ({ default: jest.fn(() => Promise.resolve([
        { label: 'New', value: 'New' },
        { label: 'Processed', value: 'Processed' },
        { label: 'Accounts Merged', value: 'Accounts Merged' }
    ])) }),
    { virtual: true }
);
const mockMergeRecord = jest.fn(() => Promise.resolve('Records merged'));
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.mergeRecord',
    () => ({ default: (...args) => mockMergeRecord(...args) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.removeRecord',
    () => ({ default: jest.fn(() => Promise.resolve('removed')) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.mergeAccounts',
    () => ({ default: jest.fn(() => Promise.resolve('merged')) }),
    { virtual: true }
);
// the grid child (rendered in grid view) statically imports these; provide stubs
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.getGridFieldOptions',
    () => ({ default: jest.fn(() => Promise.resolve({ leadFields: [{ name: 'Id', label: 'Record ID', type: 'id' }], fields: [], trailFields: [] })) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.getGridData',
    () => ({ default: jest.fn(() => Promise.resolve({ columns: [], groups: [] })) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.saveGridFieldConfig',
    () => ({ default: jest.fn(() => Promise.resolve()) }),
    { virtual: true }
);
jest.mock(
    '@salesforce/apex/MRG_DuplicateMerge_CTRL.mergeRecords',
    () => ({ default: jest.fn(() => Promise.resolve('merged')) }),
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

// one keep with two duplicate pairs, ordered by confidence desc
const KEEP_GROUPS = [
    {
        keepId: '001A', keepName: 'Acme', objectType: 'Account', keepLink: '/001A',
        pairs: [
            { id: 'p1', mergeId: '001B', mergeName: 'Acme 2', mergeLink: '/001B', confidenceScore: 90, autoMerge: false },
            { id: 'p2', mergeId: '001C', mergeName: 'Acme 3', mergeLink: '/001C', confidenceScore: 80, autoMerge: false }
        ]
    }
];

function flush() {
    return Promise.resolve();
}
function previewButtons(el) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-button')).filter(b => b.label === 'Preview');
}
function mergeButton(el, recordId) {
    return Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
        .find(b => b.label === 'Merge' && b.dataset.record === recordId);
}
function groupPager(el) {
    return Array.from(el.shadowRoot.querySelectorAll('c-pager')).find(p => !p.dataset.keep);
}
function pairPager(el) {
    return Array.from(el.shadowRoot.querySelectorAll('c-pager')).find(p => p.dataset.keep);
}
function makeGroups(n, pairsEach) {
    return Array.from({ length: n }, (_, i) => ({
        keepId: 'k' + i, keepName: 'Keep' + i, objectType: 'Account', keepLink: '/k' + i,
        pairs: Array.from({ length: pairsEach }, (_, j) => ({
            id: 'k' + i + 'p' + j, mergeId: 'm' + i + j, mergeName: 'M' + i + j, mergeLink: '/m' + i + j,
            confidenceScore: 90 - j, autoMerge: false
        }))
    }));
}
async function renderGroups(groups) {
    const el = createElement('c-dupe-list', { is: DupeList });
    document.body.appendChild(el);
    getKeepGroups.emit(groups);
    await Promise.resolve();
    await Promise.resolve();
    return el;
}

describe('c-dupe-list', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    async function render() {
        const el = createElement('c-dupe-list', { is: DupeList });
        document.body.appendChild(el);
        getKeepGroups.emit(KEEP_GROUPS);
        await flush();
        await flush();
        return el;
    }

    it('renders a row per (keep, merge) pair within the keep group', async () => {
        const el = await render();
        expect(previewButtons(el).length).toBe(2);
    });

    it('merging a pair removes only that pair from the group', async () => {
        const el = await render();
        expect(previewButtons(el).length).toBe(2);

        mergeButton(el, 'p1').dispatchEvent(new CustomEvent('click'));
        await flush();
        await flush();
        await flush();

        expect(mockMergeRecord).toHaveBeenCalledWith({ recordId: 'p1' });
        expect(previewButtons(el).length).toBe(1); // the other pair survives
    });

    it('pages through duplicate groups with the outer pager (10 per page)', async () => {
        const el = await renderGroups(makeGroups(12, 1));
        expect(groupPager(el)).toBeTruthy();
        expect(previewButtons(el).length).toBe(10); // first page of groups

        groupPager(el).dispatchEvent(new CustomEvent('page', { detail: 2, bubbles: true }));
        await flush();
        expect(previewButtons(el).length).toBe(2); // remaining 2 groups
    });

    it('pages through duplicates within a group with the inner pager (5 per page)', async () => {
        const el = await renderGroups(makeGroups(1, 7));
        expect(previewButtons(el).length).toBe(5); // first page of duplicates
        const ip = pairPager(el);
        expect(ip).toBeTruthy();

        ip.dispatchEvent(new CustomEvent('page', { detail: 2, bubbles: true }));
        await flush();
        expect(previewButtons(el).length).toBe(2); // remaining 2 duplicates
    });

    it('toggles to the grid view and renders the grid component', async () => {
        const el = await render();
        const toggle = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Grid View');
        expect(toggle).toBeTruthy();
        expect(el.shadowRoot.querySelector('c-merge-candidate-grid')).toBeNull();

        toggle.dispatchEvent(new CustomEvent('click'));
        await flush();
        await flush();
        expect(el.shadowRoot.querySelector('c-merge-candidate-grid')).toBeTruthy();
    });
});
