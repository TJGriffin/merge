import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getKeepGroups from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getKeepGroups';
import getDuplicateRules from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getRules';
import getCount from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getCount';
import doMergeRecord from '@salesforce/apex/MRG_DuplicateMerge_CTRL.mergeRecord';
import doRemoveRecord from '@salesforce/apex/MRG_DuplicateMerge_CTRL.removeRecord';
import doMergeAccounts from '@salesforce/apex/MRG_DuplicateMerge_CTRL.mergeAccounts';

export default class DupeList extends LightningElement {
    @track objectType;
    @track keepGroups;
    @track rule;
    @track error;
    @track limitAmt = 100;
    @track offsetAmt;
    @track totalRows;
    @track totalPages;
    @track currentPage;
    @track selectedRecordId;
    @track navItems = [];
    @track isModalOpen = false;
    @track showSpinner = false;

    get hasPager(){
        return this.totalPages != null && this.totalPages !== undefined;
    }
    get hasGroups(){
        return this.keepGroups != null && this.keepGroups.length > 0;
    }

    set countValue(value){
        this.totalRows = value != null ? Number(value) : null;
        this.totalPages = this.totalRows !== undefined && this.totalRows != null && this.totalRows > this.limitAmt ? Number(Math.ceil(this.totalRows / this.limitAmt)) : 1;
        this.currentPage = this.currentPage === undefined || this.currentPage == null ? 1 : this.currentPage;
    }
    get countValue(){
        return this.totalRows;
    }

    set rules(value) {
        if(typeof value !== 'undefined' && value != null) {
            var options = [];
            var parsedVal = JSON.parse(JSON.stringify(value));
            var arr = Array.isArray(parsedVal) ? parsedVal : [parsedVal];
            arr.forEach(rule=>{
                options.push({ label: rule.ruleName, value: rule.ruleName });
            });
            this.ruleOptions = options;
        }
    }
    get rules(){
        return this.ruleOptions;
    }
    @track ruleOptions;

    objectOptions = [{label:'Account',value:'Account'},{label:'Contact', value:'Contact'}];
    notificationBody;
    notificationStyle;
    notificationTitle;

    connectedCallback(){
        var objectisNull = this.objectType == null || this.objectType === undefined;
        this.limitAmt = this.limitAmt == null || this.limitAmt === undefined ? 100 : Number(this.limitAmt);
        this.offsetAmt = this.offsetAmt == null || this.offsetAmt === undefined ? 0 : this.offsetAmt;
        this.objectType = objectisNull ? 'Contact' : this.objectType;
        if(objectisNull){
            this.fetchRules();
        }
    }

    @wire(getKeepGroups, {objectType:'$objectType',ruleName:'$rule',limitAmt:'$limitAmt',offsetAmt:'$offsetAmt'})
        getRowData({error, data}) {
            if(data){
                this.keepGroups = this.decorate(data);
                this.showSpinner = false;
                this.fetchCount();
            } else if(error){
                this.showSpinner = false;
                this.keepGroups = undefined;
                this.error = error;
                this.handleError();
            }
        }

    decorate(data){
        return JSON.parse(JSON.stringify(data)).map(group=>{
            group.pairs = (group.pairs || []).map(pair=>{
                pair.confidenceDisplay = (pair.confidenceScore != null && pair.confidenceScore !== undefined) ? pair.confidenceScore : '—';
                return pair;
            });
            group.pairCount = group.pairs.length;
            return group;
        });
    }

    fetchCount(){
        getCount({objectType:this.objectType,ruleName:this.rule})
            .then(result=>{ this.countValue = result; })
            .catch(error=>{ this.error=error; this.handleError(); });
    }
    fetchRules(){
        getDuplicateRules({objectType:this.objectType})
            .then(result=>{ this.rules = result; })
            .catch(error=>{ this.error=error; this.handleError(); });
    }

    handleRuleFilterChange(event){
        this.rule = event.detail.value;
        this.totalRows = null;
        this.currentPage = null;
    }
    handleObjectFilterChange(event){
        if(this.objectType != event.detail.value){
            this.totalRows = null;
            this.currentPage = null;
            this.objectType = event.detail.value;
            this.fetchRules();
            this.rule = null;
        }
    }
    handlePager(event){
        this.currentPage = Number(event.detail);
        this.offsetAmt = Number((this.currentPage - 1) * Number(this.limitAmt));
    }

    // ---- preview modal + in-group navigation ----
    handlePreview(event){
        var pairId = event.currentTarget.dataset.record;
        var keepId = event.currentTarget.dataset.keep;
        var group = (this.keepGroups || []).find(g=>g.keepId == keepId);
        this.navItems = group ? group.pairs.map(pair=>this.toNavItem(pair, pairId)) : [];
        this.selectedRecordId = pairId;
        this.isModalOpen = true;
    }
    toNavItem(pair, selectedId){
        var conf = (pair.confidenceScore != null && pair.confidenceScore !== undefined) ? ' — ' + pair.confidenceScore : '';
        return {
            id: pair.id,
            label: (pair.mergeName || pair.mergeId) + conf,
            variant: pair.id === selectedId ? 'brand' : 'neutral'
        };
    }
    refreshNavVariants(){
        this.navItems = this.navItems.map(nav=>({ id:nav.id, label:nav.label, variant: nav.id === this.selectedRecordId ? 'brand' : 'neutral' }));
    }
    get currentNavIndex(){
        return this.navItems.findIndex(nav=>nav.id === this.selectedRecordId);
    }
    get hasPrevDisabled(){
        return !(this.currentNavIndex > 0);
    }
    get hasNextDisabled(){
        return !(this.currentNavIndex > -1 && this.currentNavIndex < this.navItems.length - 1);
    }
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
    handleModalRemove(){
        this.isModalOpen = false;
        this.showSpinner = true;
        this.removeRecord();
    }
    handleModalMerge(){
        this.isModalOpen = false;
        this.showSpinner = true;
        this.mergeRecord();
    }

    // ---- inline row actions ----
    handleMerge(event){
        this.showSpinner = true;
        this.selectedRecordId = event.currentTarget.dataset.record;
        this.mergeRecord();
    }
    handleRemove(event){
        this.showSpinner = true;
        this.selectedRecordId = event.currentTarget.dataset.record;
        this.removeRecord();
    }
    handleMergeAccounts(event){
        this.showSpinner = true;
        this.selectedRecordId = event.currentTarget.dataset.record;
        this.mergeAccounts();
    }

    // ---- apex calls ----
    mergeRecord(){
        doMergeRecord({recordId:this.selectedRecordId})
            .then(response=>{ this.removeSelectedPair(); this.notificationBody=response; this.handleSuccess(); })
            .catch(error=>{ this.error=error; this.handleError(); });
    }
    removeRecord(){
        doRemoveRecord({recordId:this.selectedRecordId})
            .then(response=>{ this.removeSelectedPair(); this.notificationBody=response; this.handleSuccess(); })
            .catch(error=>{ this.error=error; this.handleError(); });
    }
    mergeAccounts(){
        doMergeAccounts({recordId:this.selectedRecordId})
            .then(response=>{ this.removeSelectedPair(); this.notificationBody=response; this.handleSuccess(); })
            .catch(error=>{ this.error=error; this.handleError(); });
    }
    removeSelectedPair(){
        var id = this.selectedRecordId;
        var groups = [];
        (this.keepGroups || []).forEach(group=>{
            var pairs = (group.pairs || []).filter(pair=>pair.id != id);
            if(pairs.length > 0){
                group.pairs = pairs;
                group.pairCount = pairs.length;
                groups.push(group);
            }
        });
        this.keepGroups = groups;
        this.selectedRecordId = null;
    }

    handleSuccess(){
        this.showSpinner=false;
        this.notificationTitle = 'Record Saved';
        this.notificationStyle='success';
        this.notificationBody = this.notificationBody == null ? 'Success' : this.notificationBody;
        this.showNotification();
    }
    handleError(){
        this.showSpinner=false;
        this.notificationTitle = 'An error has occurred';
        this.notificationStyle = 'error';
        this.notificationBody = 'Unknown error';
        if(this.error && this.error.body){
            if(Array.isArray(this.error.body)) this.notificationBody = this.error.body.map(e=>e.message).join(', ');
            else if(typeof this.error.body.message === 'string') this.notificationBody = this.error.body.message;
        }
        this.showNotification();
    }
    showNotification(){
        this.dispatchEvent(new ShowToastEvent({ title:this.notificationTitle, message:this.notificationBody, variant:this.notificationStyle }));
    }
}
