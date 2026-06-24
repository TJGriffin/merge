import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getKeepGroups from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getKeepGroups';
import getGridRows from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getGridRows';
import getGridFieldOptions from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getGridFieldOptions';
import getCount from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getCount';
import saveGridFieldConfig from '@salesforce/apex/MRG_DuplicateMerge_CTRL.saveGridFieldConfig';
import mergeRecords from '@salesforce/apex/MRG_DuplicateMerge_CTRL.mergeRecords';
import removeRecords from '@salesforce/apex/MRG_DuplicateMerge_CTRL.removeRecords';
import mergeAccountsBulk from '@salesforce/apex/MRG_DuplicateMerge_CTRL.mergeAccountsBulk';
import runActionOverFilter from '@salesforce/apex/MRG_DuplicateMerge_CTRL.runActionOverFilter';

// the grid mirrors the list view's two-level paging: it loads the working set of groups (up to CAP)
// via getKeepGroups, pages groups (outer) and duplicates within a group (inner) client-side, and lazily
// fetches the field values + simulated merge result for only the groups currently in view (getGridRows).
const CAP = 2000;
const PAIRS_PER_PAGE = 5;
const DEFAULT_GROUPS_PER_PAGE = 10;
const GROUP_PAGE_OPTIONS = [
    {label:'5', value:'5'}, {label:'10', value:'10'}, {label:'25', value:'25'}, {label:'50', value:'50'}
];

export default class MergeCandidateGrid extends LightningElement {
    @api objectType;

    _filter;
    @api
    get filter(){ return this._filter; }
    set filter(value){
        this._filter = value;
        this.clearSelection();
        if(this._loaded)
            this.load();
    }

    @track allGroups = [];
    @track columns = [];
    @track rowsByKeep = {};
    @track panelFields = [];
    leadFields = [];
    trailFields = [];
    filterText = '';
    fieldsDirty = false;
    currentGroupPage = 1;
    groupsPerPage = DEFAULT_GROUPS_PER_PAGE;
    totalCandidates = 0;
    selectedCandidateIds = [];
    selectAllMax = false;
    showFieldPanel = false;
    loadingGroups = false;
    rowsLoading = false;
    // preview modal
    isModalOpen = false;
    selectedRecordId;
    @track navItems = [];

    groupPageOptions = GROUP_PAGE_OPTIONS;
    _loaded = false;

    connectedCallback(){
        this.loadFieldOptions();
    }

    // ---- field options + selection persistence ----
    loadFieldOptions(){
        if(!this.objectType)
            return;
        getGridFieldOptions({objectType:this.objectType})
            .then(result=>{
                this.leadFields = result.leadFields || [];
                this.trailFields = result.trailFields || [];
                this.panelFields = (result.fields || []).map(o=>Object.assign({}, o));
                this._loaded = true;
                this.load();
            })
            .catch(error=>this.handleError(error));
    }
    get selectedNames(){
        return this.panelFields.filter(f=>f.selected).map(f=>f.name);
    }
    get fieldNames(){
        return this.leadFields.map(f=>f.name)
            .concat(this.selectedNames)
            .concat(this.trailFields.map(f=>f.name));
    }

    // ---- load groups (working set) + counts ----
    load(){
        if(!this.objectType || !this._filter)
            return;
        this.loadingGroups = true;
        Promise.all([
            getKeepGroups({filter:this._filter, limitAmt:CAP, offsetAmt:0}),
            getCount({filter:this._filter})
        ]).then(results=>{
            this.allGroups = (results[0] || []).map(g=>Object.assign({}, g, {pairPage:1}));
            this.totalCandidates = results[1] != null ? Number(results[1]) : 0;
            this.currentGroupPage = 1;
            this.loadingGroups = false;
            this.loadVisibleRows();
        }).catch(error=>{ this.loadingGroups = false; this.handleError(error); });
    }
    // the groups on the current outer page
    get currentGroups(){
        const start = (this.currentGroupPage - 1) * this.groupsPerPage;
        return this.allGroups.slice(start, start + this.groupsPerPage);
    }
    // fetch field values + simulated result for the groups currently in view only
    loadVisibleRows(){
        const ids = [];
        this.currentGroups.forEach(g=>(g.pairs || []).forEach(p=>ids.push(p.id)));
        if(!ids.length){
            this.rowsByKeep = {};
            this.columns = [];
            return;
        }
        this.rowsLoading = true;
        getGridRows({objectType:this.objectType, fields:this.fieldNames, candidateIds:ids})
            .then(resp=>{
                this.columns = (resp && resp.columns) ? resp.columns : [];
                this.rowsByKeep = this.indexRows((resp && resp.groups) ? resp.groups : []);
                this.rowsLoading = false;
            })
            .catch(error=>{ this.rowsLoading = false; this.handleError(error); });
    }
    indexRows(groups){
        const map = {};
        groups.forEach(g=>{
            const entry = { keepCells: [], resultCells: [], dupByCandidate: {} };
            (g.rows || []).forEach(r=>{
                if(r.rowType === 'keep') entry.keepCells = r.cells;
                else if(r.rowType === 'result') entry.resultCells = r.cells;
                else if(r.rowType === 'duplicate'){
                    if(!entry.dupByCandidate[r.candidateId]) entry.dupByCandidate[r.candidateId] = [];
                    entry.dupByCandidate[r.candidateId].push({ recordId: r.recordId, cells: r.cells });
                }
            });
            map[g.keepId] = entry;
        });
        return map;
    }

    // ---- rendered groups (structure + lazily-loaded rows, sliced to inner page) ----
    get pagedGroups(){
        const selected = new Set(this.selectedCandidateIds);
        return this.currentGroups.map(g=>{
            const rows = this.rowsByKeep[g.keepId];
            const pairPage = g.pairPage || 1;
            const pairs = g.pairs || [];
            const visiblePairs = pairs.slice((pairPage - 1) * PAIRS_PER_PAGE, pairPage * PAIRS_PER_PAGE);
            const displayRows = [];
            if(rows){
                displayRows.push(this.staticRow(g.keepId, 'keep', 'Keep', 'grid-row_keep', rows.keepCells));
                visiblePairs.forEach(p=>{
                    const checked = this.selectAllMax || selected.has(p.id);
                    (rows.dupByCandidate[p.id] || []).forEach((d, di)=>{
                        displayRows.push({
                            key: g.keepId + '-dup-' + p.id + '-' + di,
                            rowType: 'duplicate', rowLabel: 'Duplicate', rowClass: 'grid-row_duplicate',
                            selectable: true, candidateId: p.id, keepId: g.keepId, checked: checked, cells: d.cells
                        });
                    });
                });
                displayRows.push(this.staticRow(g.keepId, 'result', 'Result', 'grid-row_result', rows.resultCells));
            }
            return {
                keepId: g.keepId,
                keepName: g.keepName,
                pairCount: pairs.length,
                pairPage: pairPage,
                pairTotalPages: Math.max(1, Math.ceil(pairs.length / PAIRS_PER_PAGE)),
                showPairPager: pairs.length > PAIRS_PER_PAGE,
                hasRows: !!rows,
                displayRows: displayRows
            };
        });
    }
    staticRow(keepId, rowType, rowLabel, rowClass, cells){
        return { key: keepId + '-' + rowType, rowType: rowType, rowLabel: rowLabel, rowClass: rowClass,
            selectable: false, candidateId: null, keepId: keepId, checked: false, cells: cells || [] };
    }
    get hasGroups(){ return this.allGroups.length > 0; }
    get showSpinner(){ return this.loadingGroups || this.rowsLoading; }

    // ---- outer (group) + inner (within-group) paging ----
    get groupTotalPages(){ return Math.max(1, Math.ceil(this.allGroups.length / this.groupsPerPage)); }
    get hasGroupPager(){ return this.allGroups.length > this.groupsPerPage; }
    handleGroupPage(event){
        this.currentGroupPage = Number(event.detail);
        this.loadVisibleRows();
    }
    handlePairPage(event){
        const keepId = event.currentTarget.dataset.keep;
        const page = Number(event.detail);
        this.allGroups = this.allGroups.map(g=> g.keepId == keepId ? Object.assign({}, g, {pairPage:page}) : g);
    }
    get groupsPerPageValue(){ return String(this.groupsPerPage); }
    handleGroupsPerPageChange(event){
        this.groupsPerPage = Number(event.detail.value);
        this.currentGroupPage = 1;
        this.loadVisibleRows();
    }
    get cappedNotice(){
        return this.totalCandidates > CAP
            ? 'Showing the ' + CAP + ' highest-confidence candidates of ' + this.totalCandidates + ' total.'
            : null;
    }

    // ---- selection ----
    handleRowSelect(event){
        const candidateId = event.currentTarget.dataset.candidate;
        const checked = event.target.checked;
        // a manual toggle exits "all maximum" mode and becomes an explicit selection
        if(this.selectAllMax){
            this.selectAllMax = false;
            this.selectedCandidateIds = this.allPageCandidateIds();
        }
        const set = new Set(this.selectedCandidateIds);
        if(checked) set.add(candidateId); else set.delete(candidateId);
        this.selectedCandidateIds = Array.from(set);
    }
    allPageCandidateIds(){
        const ids = [];
        this.currentGroups.forEach(g=>(g.pairs || []).forEach(p=>ids.push(p.id)));
        return ids;
    }
    handleSelectAllPage(){
        this.selectAllMax = false;
        this.selectedCandidateIds = this.allPageCandidateIds();
    }
    handleSelectAllMax(){
        this.selectAllMax = true;
        this.selectedCandidateIds = [];
    }
    clearSelection(){
        this.selectedCandidateIds = [];
        this.selectAllMax = false;
    }
    handleClearSelection(){ this.clearSelection(); }
    get hasSelection(){ return this.selectAllMax || this.selectedCandidateIds.length > 0; }
    get actionsDisabled(){ return !this.hasSelection; }
    get selectionLabel(){
        if(this.selectAllMax)
            return 'All ' + this.totalCandidates + ' matching selected';
        if(this.selectedCandidateIds.length)
            return this.selectedCandidateIds.length + ' selected';
        return null;
    }

    // ---- bulk actions ----
    handleMergeSelected(){ this.runAction('merge', mergeRecords); }
    handleRemoveSelected(){ this.runAction('remove', removeRecords); }
    handleMergeAccountsSelected(){ this.runAction('mergeAccounts', mergeAccountsBulk); }
    runAction(action, idAction){
        if(!this.hasSelection)
            return;
        if(this.selectAllMax){
            // operate over every matching candidate in the background
            runActionOverFilter({filter:this._filter, action:action})
                .then(()=>{
                    this.toast('Started', 'Processing all ' + this.totalCandidates + ' matching candidates in the background.', 'success');
                    this.clearSelection();
                })
                .catch(error=>this.handleError(error));
            return;
        }
        this.rowsLoading = true;
        idAction({recordIds:this.selectedCandidateIds})
            .then(response=>{
                this.toast('Success', response, 'success');
                this.clearSelection();
                this.load();
            })
            .catch(error=>{ this.rowsLoading = false; this.handleError(error); });
    }

    // ---- field side panel ----
    toggleFieldPanel(){ this.showFieldPanel = !this.showFieldPanel; }
    get hasOptionalFields(){ return this.panelFields.length > 0; }
    get visibleFields(){
        const text = (this.filterText || '').toLowerCase();
        const selected = this.panelFields.filter(f=>f.selected);
        return this.panelFields
            .filter(f=>
                !text
                || (f.label || '').toLowerCase().indexOf(text) !== -1
                || (f.name || '').toLowerCase().indexOf(text) !== -1)
            .map(f=>Object.assign({}, f, {
                disableMoveUp: !(f.selected && selected.indexOf(f) > 0),
                disableMoveDown: !(f.selected && selected.indexOf(f) < selected.length - 1)
            }));
    }
    handleFilterChange(event){ this.filterText = event.detail.value; }
    handleFieldToggle(event){
        const name = event.currentTarget.dataset.field;
        const checked = event.target.checked;
        this.panelFields = this.panelFields.map(f=> f.name === name ? Object.assign({}, f, {selected:checked}) : f);
        this.fieldsDirty = true;
    }
    handleMoveUp(event){ this.moveSelected(event.currentTarget.dataset.field, -1); }
    handleMoveDown(event){ this.moveSelected(event.currentTarget.dataset.field, 1); }
    moveSelected(name, dir){
        const arr = this.panelFields.slice();
        const i = arr.findIndex(f=>f.name === name);
        if(i < 0 || !arr[i].selected)
            return;
        let j = i + dir;
        while(j >= 0 && j < arr.length && !arr[j].selected)
            j += dir;
        if(j < 0 || j >= arr.length)
            return;
        const tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp;
        this.panelFields = arr;
        this.fieldsDirty = true;
    }
    get saveFieldsDisabled(){ return !this.fieldsDirty; }
    handleSaveFields(){
        saveGridFieldConfig({objectType:this.objectType, fields:this.selectedNames})
            .then(()=>{
                this.fieldsDirty = false;
                this.resortPanel();
                this.showFieldPanel = false;
                this.loadVisibleRows();
                this.toast('Fields saved', 'Grid fields updated.', 'success');
            })
            .catch(error=>this.handleError(error));
    }
    resortPanel(){
        const selected = this.panelFields.filter(f=>f.selected);
        const unselected = this.panelFields.filter(f=>!f.selected)
            .slice()
            .sort((a,b)=>(a.label || '').toLowerCase().localeCompare((b.label || '').toLowerCase()));
        this.panelFields = selected.concat(unselected);
    }

    // ---- preview modal with in-group navigation (mirrors the list view) ----
    handlePreview(event){
        const candidateId = event.currentTarget.dataset.record;
        const keepId = event.currentTarget.dataset.keep;
        const group = (this.allGroups || []).find(g=>g.keepId == keepId);
        this.navItems = group ? group.pairs.map(p=>this.toNavItem(p, candidateId)) : [];
        this.selectedRecordId = candidateId;
        this.isModalOpen = true;
    }
    toNavItem(pair, selectedId){
        const conf = (pair.confidenceScore != null && pair.confidenceScore !== undefined) ? ' — ' + pair.confidenceScore : '';
        return {
            id: pair.id,
            label: (pair.mergeName || pair.mergeId) + conf,
            variant: pair.id === selectedId ? 'brand' : 'neutral'
        };
    }
    refreshNavVariants(){
        this.navItems = this.navItems.map(n=>({ id:n.id, label:n.label, variant: n.id === this.selectedRecordId ? 'brand' : 'neutral' }));
    }
    get currentNavIndex(){ return this.navItems.findIndex(n=>n.id === this.selectedRecordId); }
    get hasPrevDisabled(){ return !(this.currentNavIndex > 0); }
    get hasNextDisabled(){ return !(this.currentNavIndex > -1 && this.currentNavIndex < this.navItems.length - 1); }
    handleNavSelect(event){
        this.selectedRecordId = event.currentTarget.dataset.record;
        this.refreshNavVariants();
    }
    handlePrev(){
        if(this.currentNavIndex > 0){
            this.selectedRecordId = this.navItems[this.currentNavIndex - 1].id;
            this.refreshNavVariants();
        }
    }
    handleNext(){
        if(this.currentNavIndex > -1 && this.currentNavIndex < this.navItems.length - 1){
            this.selectedRecordId = this.navItems[this.currentNavIndex + 1].id;
            this.refreshNavVariants();
        }
    }
    closeModal(){
        this.isModalOpen = false;
        this.selectedRecordId = null;
    }
    handleModalMerge(){
        const id = this.selectedRecordId;
        this.isModalOpen = false;
        this.rowsLoading = true;
        mergeRecords({recordIds:[id]})
            .then(response=>{ this.toast('Success', response, 'success'); this.load(); })
            .catch(error=>{ this.rowsLoading = false; this.handleError(error); });
    }
    handleModalRemove(){
        const id = this.selectedRecordId;
        this.isModalOpen = false;
        this.rowsLoading = true;
        removeRecords({recordIds:[id]})
            .then(response=>{ this.toast('Success', response, 'success'); this.load(); })
            .catch(error=>{ this.rowsLoading = false; this.handleError(error); });
    }

    // ---- notifications ----
    toast(title, message, variant){
        this.dispatchEvent(new ShowToastEvent({ title:title, message:message, variant:variant }));
    }
    handleError(error){
        let message = 'Unknown error';
        if(error && error.body){
            if(Array.isArray(error.body)) message = error.body.map(e=>e.message).join(', ');
            else if(typeof error.body.message === 'string') message = error.body.message;
        }
        this.toast('An error has occurred', message, 'error');
    }
}
