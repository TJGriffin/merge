import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getKeepGroups from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getKeepGroups';
import getDuplicateRules from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getRules';
import getCount from '@salesforce/apex/MRG_DuplicateMerge_CTRL.getCount';
import doMergeRecord from '@salesforce/apex/MRG_DuplicateMerge_CTRL.mergeRecord';
import doRemoveRecord from '@salesforce/apex/MRG_DuplicateMerge_CTRL.removeRecord';
import doMergeAccounts from '@salesforce/apex/MRG_DuplicateMerge_CTRL.mergeAccounts';

// the highest-confidence duplicates are fetched in one governor-safe query (no GROUP BY /
// COUNT_DISTINCT, which throw past 50k candidates), then paged client-side: an outer pager over
// duplicate groups and an inner pager over the duplicates within each group.
const CAP = 2000;
const GROUPS_PER_PAGE = 10;
const PAIRS_PER_PAGE = 5;

export default class DupeList extends LightningElement {
    @track objectType;
    @track rule;
    @track error;
    @track allGroups = [];
    @track currentGroupPage = 1;
    @track totalDuplicates;
    @track selectedRecordId;
    @track navItems = [];
    @track isModalOpen = false;
    @track showSpinner = false;
    @track ruleOptions;

    objectOptions = [{label:'Account',value:'Account'},{label:'Contact', value:'Contact'}];
    notificationBody;
    notificationStyle;
    notificationTitle;

    connectedCallback(){
        if(this.objectType == null || this.objectType === undefined){
            this.objectType = 'Contact';
            this.fetchRules();
        }
    }

    @wire(getKeepGroups, {objectType:'$objectType', ruleName:'$rule', limitAmt: CAP, offsetAmt: 0})
        getRowData({error, data}) {
            if(data){
                this.allGroups = this.decorate(data);
                this.currentGroupPage = 1;
                this.showSpinner = false;
                this.fetchCount();
            } else if(error){
                this.showSpinner = false;
                this.allGroups = [];
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
            group.pairPage = 1;
            return group;
        });
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

    get hasGroups(){
        return this.allGroups != null && this.allGroups.length > 0;
    }
    get groupTotalPages(){
        return Math.max(1, Math.ceil(this.allGroups.length / GROUPS_PER_PAGE));
    }
    get hasGroupPager(){
        return this.allGroups.length > GROUPS_PER_PAGE;
    }
    // the groups on the current outer page, each sliced to its current inner (duplicates) page
    get pagedGroups(){
        const start = (this.currentGroupPage - 1) * GROUPS_PER_PAGE;
        return this.allGroups.slice(start, start + GROUPS_PER_PAGE).map(g=>{
            const pairPage = g.pairPage || 1;
            return {
                keepId: g.keepId,
                keepName: g.keepName,
                keepLink: g.keepLink,
                objectType: g.objectType,
                pairCount: g.pairCount,
                pairPage: pairPage,
                pairTotalPages: Math.max(1, Math.ceil(g.pairs.length / PAIRS_PER_PAGE)),
                showPairPager: g.pairs.length > PAIRS_PER_PAGE,
                visiblePairs: g.pairs.slice((pairPage - 1) * PAIRS_PER_PAGE, pairPage * PAIRS_PER_PAGE)
            };
        });
    }
    // when more duplicates exist than the fetched cap, tell the user this is the top slice
    get cappedNotice(){
        return (this.totalDuplicates != null && this.totalDuplicates > CAP)
            ? 'Showing the ' + CAP + ' highest-confidence duplicates of ' + this.totalDuplicates +
              ' total. Work the top matches, then refresh for the next set.'
            : null;
    }

    fetchCount(){
        getCount({objectType:this.objectType,ruleName:this.rule})
            .then(result=>{ this.totalDuplicates = result != null ? Number(result) : null; })
            .catch(error=>{ this.error=error; this.handleError(); });
    }
    fetchRules(){
        getDuplicateRules({objectType:this.objectType})
            .then(result=>{ this.rules = result; })
            .catch(error=>{ this.error=error; this.handleError(); });
    }

    handleRuleFilterChange(event){
        this.rule = event.detail.value;
        this.currentGroupPage = 1;
    }
    handleObjectFilterChange(event){
        if(this.objectType != event.detail.value){
            this.currentGroupPage = 1;
            this.objectType = event.detail.value;
            this.fetchRules();
            this.rule = null;
        }
    }
    handleGroupPage(event){
        this.currentGroupPage = Number(event.detail);
    }
    handlePairPage(event){
        const keepId = event.currentTarget.dataset.keep;
        const page = Number(event.detail);
        this.allGroups = this.allGroups.map(g=> g.keepId == keepId ? Object.assign({}, g, { pairPage: page }) : g);
    }

    // ---- preview modal + in-group navigation ----
    handlePreview(event){
        var pairId = event.currentTarget.dataset.record;
        var keepId = event.currentTarget.dataset.keep;
        var group = (this.allGroups || []).find(g=>g.keepId == keepId);
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
        (this.allGroups || []).forEach(group=>{
            var pairs = (group.pairs || []).filter(pair=>pair.id != id);
            if(pairs.length > 0){
                group.pairs = pairs;
                group.pairCount = pairs.length;
                var maxPage = Math.max(1, Math.ceil(pairs.length / PAIRS_PER_PAGE));
                if((group.pairPage || 1) > maxPage){
                    group.pairPage = maxPage;
                }
                groups.push(group);
            }
        });
        this.allGroups = groups;
        if(this.currentGroupPage > this.groupTotalPages){
            this.currentGroupPage = this.groupTotalPages;
        }
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
