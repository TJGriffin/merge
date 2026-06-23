import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getGridData from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getGridData';
import getGridFieldOptions from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getGridFieldOptions';
import getCount from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getCount';
import saveGridFieldConfig from '@salesforce/apex/MRG_DuplicateMerge_CTRL.saveGridFieldConfig';
import mergeRecords from '@salesforce/apex/MRG_DuplicateMerge_CTRL.mergeRecords';
import removeRecords from '@salesforce/apex/MRG_DuplicateMerge_CTRL.removeRecords';
import mergeAccountsBulk from '@salesforce/apex/MRG_DuplicateMerge_CTRL.mergeAccountsBulk';

// the grid shows a page of candidates grouped by kept record (keep / duplicate(s) / simulated result),
// for a configurable field set. Only Id/Created/LastModified always appear; every other field is toggled
// in the side panel and the selection is saved per object for all users. Paging is bounded to the top
// 2000 confidence-ranked candidates, matching the list view.
const DEFAULT_PAGE_SIZE = 50;
const MAX_RECORDS = 2000;
const PAGE_SIZE_OPTIONS = [
    {label:'10', value:'10'}, {label:'25', value:'25'}, {label:'50', value:'50'},
    {label:'100', value:'100'}, {label:'200', value:'200'}
];

export default class MergeCandidateGrid extends LightningElement {
    @api objectType;

    _filter;
    @api
    get filter(){ return this._filter; }
    set filter(value){
        this._filter = value;
        this.pageNumber = 1;
        this.selectedCandidateIds = [];
        if(this._loaded)
            this.reload();
    }

    @track columns = [];
    @track groups = [];
    @track allFields = [];
    leadFields = [];
    trailFields = [];
    filterText = '';
    fieldsDirty = false;
    selectedCandidateIds = [];
    pageSize = DEFAULT_PAGE_SIZE;
    pageNumber = 1;
    totalCandidates = 0;
    showFieldPanel = false;
    showSpinner = false;
    pageSizeOptions = PAGE_SIZE_OPTIONS;
    error;
    _loaded = false;

    connectedCallback(){
        this.loadFieldOptions();
    }

    loadFieldOptions(){
        if(!this.objectType)
            return;
        getGridFieldOptions({objectType:this.objectType})
            .then(result=>{
                this.leadFields = result.leadFields || [];
                this.trailFields = result.trailFields || [];
                // server returns every selectable field (label-sorted) with its saved/default selected state
                this.allFields = (result.fields || []).map(o=>Object.assign({}, o));
                this._loaded = true;
                this.reload();
            })
            .catch(error=>this.handleError(error));
    }

    // selected field API names, in label order (allFields arrives label-sorted from the server)
    get selectedNames(){
        return this.allFields.filter(f=>f.selected).map(f=>f.name);
    }
    // the ordered field API names sent to the server: Id, selected fields (label order), Created/Last Modified
    get fieldNames(){
        var names = this.leadFields.map(f=>f.name);
        names = names.concat(this.selectedNames);
        names = names.concat(this.trailFields.map(f=>f.name));
        return names;
    }

    reload(){
        if(!this.objectType || !this._filter)
            return;
        this.showSpinner = true;
        Promise.all([
            getGridData({filter:this._filter, fields:this.fieldNames, pageSize:this.pageSize, pageNumber:this.pageNumber}),
            getCount({filter:this._filter})
        ]).then(results=>{
            var grid = results[0];
            var count = results[1];
            this.columns = (grid && grid.columns) ? grid.columns : [];
            this.groups = this.decorateGroups((grid && grid.groups) ? grid.groups : []);
            this.totalCandidates = count != null ? Number(count) : 0;
            this.showSpinner = false;
        }).catch(error=>{ this.showSpinner = false; this.handleError(error); });
    }

    decorateGroups(groups){
        return groups.map(g=>({
            keepId: g.keepId,
            keepName: g.keepName,
            objectType: g.objectType,
            rows: (g.rows || []).map((r, idx)=>this.decorateRow(g.keepId, r, idx))
        }));
    }
    decorateRow(keepId, r, idx){
        return {
            key: keepId + '|' + r.rowType + '|' + (r.recordId || '') + '|' + idx,
            rowType: r.rowType,
            rowLabel: this.rowLabel(r.rowType),
            recordId: r.recordId,
            candidateId: r.candidateId,
            selectable: r.selectable,
            checked: r.candidateId ? this.selectedCandidateIds.includes(r.candidateId) : false,
            rowClass: this.rowClass(r.rowType),
            cells: (r.cells || []).map(c=>({ key: r.rowType + '|' + (r.recordId || '') + '|' + c.name, name: c.name, value: c.value }))
        };
    }
    rowLabel(rowType){
        if(rowType === 'keep') return 'Keep';
        if(rowType === 'result') return 'Result';
        return 'Duplicate';
    }
    rowClass(rowType){
        if(rowType === 'keep') return 'slds-hint-parent grid-row_keep';
        if(rowType === 'result') return 'slds-hint-parent grid-row_result';
        return 'slds-hint-parent grid-row_duplicate';
    }

    // ---- selection ----
    handleRowSelect(event){
        var candidateId = event.currentTarget.dataset.candidate;
        var checked = event.target.checked;
        var set = new Set(this.selectedCandidateIds);
        if(checked) set.add(candidateId); else set.delete(candidateId);
        this.selectedCandidateIds = Array.from(set);
        this.refreshChecked();
    }
    refreshChecked(){
        this.groups = this.groups.map(g=>Object.assign({}, g, {
            rows: g.rows.map(r=>Object.assign({}, r, {
                checked: r.candidateId ? this.selectedCandidateIds.includes(r.candidateId) : false
            }))
        }));
    }
    get hasSelection(){ return this.selectedCandidateIds.length > 0; }
    get actionsDisabled(){ return !this.hasSelection; }

    // ---- field side panel ----
    toggleFieldPanel(){ this.showFieldPanel = !this.showFieldPanel; }
    get hasOptionalFields(){ return this.allFields.length > 0; }
    // selected fields first (label order), then the rest (label order), filtered by label or api name
    get visibleFields(){
        var text = (this.filterText || '').toLowerCase();
        var matched = this.allFields.filter(f=>
            !text
            || (f.label || '').toLowerCase().indexOf(text) !== -1
            || (f.name || '').toLowerCase().indexOf(text) !== -1);
        return matched.filter(f=>f.selected).concat(matched.filter(f=>!f.selected));
    }
    handleFilterChange(event){
        this.filterText = event.detail.value;
    }
    // toggles only update local state so the user can check/uncheck several fields before saving
    handleFieldToggle(event){
        var name = event.currentTarget.dataset.field;
        var checked = event.target.checked;
        this.allFields = this.allFields.map(f=> f.name === name ? Object.assign({}, f, {selected:checked}) : f);
        this.fieldsDirty = true;
    }
    get saveFieldsDisabled(){ return !this.fieldsDirty; }
    // persist the (multi-field) selection for this object, shared across all users, then refresh the grid
    handleSaveFields(){
        saveGridFieldConfig({objectType:this.objectType, fields:this.selectedNames})
            .then(()=>{
                this.fieldsDirty = false;
                this.pageNumber = 1;
                this.reload();
                this.toast('Fields saved', 'Grid fields updated.', 'success');
            })
            .catch(error=>this.handleError(error));
    }

    // ---- paging ----
    get pageSizeValue(){ return String(this.pageSize); }
    handlePageSizeChange(event){
        var v = Number(event.detail.value);
        if(v < 10) v = 10;
        if(v > 200) v = 200;
        this.pageSize = v;
        this.pageNumber = 1;
        this.reload();
    }
    get totalPages(){
        var capped = Math.min(this.totalCandidates, MAX_RECORDS);
        return Math.max(1, Math.ceil(capped / this.pageSize));
    }
    get hasPager(){ return this.totalPages > 1; }
    handlePage(event){
        this.pageNumber = Number(event.detail);
        this.reload();
    }
    get cappedNotice(){
        return this.totalCandidates > MAX_RECORDS
            ? 'Showing the ' + MAX_RECORDS + ' highest-confidence candidates of ' + this.totalCandidates + ' total.'
            : null;
    }

    // ---- bulk actions ----
    get hasGroups(){ return this.groups.length > 0; }
    get columnSpan(){ return this.columns.length + 1; }

    handleMergeSelected(){ this.runAction(mergeRecords); }
    handleRemoveSelected(){ this.runAction(removeRecords); }
    handleMergeAccountsSelected(){ this.runAction(mergeAccountsBulk); }
    runAction(apexFn){
        if(!this.hasSelection)
            return;
        this.showSpinner = true;
        apexFn({recordIds:this.selectedCandidateIds})
            .then(response=>{
                this.selectedCandidateIds = [];
                this.toast('Success', response, 'success');
                this.dispatchEvent(new CustomEvent('refresh'));
                this.reload();
            })
            .catch(error=>{ this.showSpinner = false; this.handleError(error); });
    }

    // ---- notifications ----
    toast(title, message, variant){
        this.dispatchEvent(new ShowToastEvent({ title:title, message:message, variant:variant }));
    }
    handleError(error){
        this.error = error;
        var message = 'Unknown error';
        if(error && error.body){
            if(Array.isArray(error.body)) message = error.body.map(e=>e.message).join(', ');
            else if(typeof error.body.message === 'string') message = error.body.message;
        }
        this.toast('An error has occurred', message, 'error');
    }
}
