import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMergeGroups from '@salesforce/apex/CON_DuplicateMerge_CTRL.getMergeGroups';
import getDuplicateRules from '@salesforce/apex/CON_DuplicateMerge_CTRL.getRules';
import getCount from '@salesforce/apex/CON_DuplicateMerge_CTRL.getCount';

export default class DupeList extends LightningElement {
    @track objectType;
    @track rows;
    @track rule;
    @track error;
    @track limitAmt = 100;
    @track offsetAmt;
    @track totalRows
    @track totalPages;
    @track currentPage;

    get hasPager(){
        return this.totalPages != null && this.totalPages !== undefined;
    }

    set countValue(value){
        console.log(value);
        this.totalRows = value != null ? Number(value) : null;
        this.totalPages = this.totalRows !== undefined && this.totalRows != null && this.totalRows > this.limitAmt ?  Number(Math.ceil(this.totalRows / this.limitAmt)) : 1; 
        this.currentPage = this.currentPage === undefined || this.currentPage == null ? 1 : this.currentPage;
        console.log('total rows');
        console.log(this.totalRows);
        console.log('totalPages');
        console.log(this.totalPages);     
    }
    get countValue(){
        return totalRows;
    }

    set rules(value) {
        if(typeof value !== 'undefined'
            && value != null) {
                var options = [];
                var arr = [];
                var parsedVal = JSON.parse(JSON.stringify(value));
                arr = Array.isArray(parsedVal) ? parsedVal : arr.push(parsedVal);
                arr.forEach(rule=>{
                    var option = {};
                    option.label = rule.ruleName;
                    option.value = rule.ruleName;
                    options.push(option);
                })
                this.ruleOptions = options;
            }
    };
    get rules(){
        return this.ruleOptions;
    }
    @track ruleOptions;

    objectOptions = [{label:'Account',value:'Account'},{label:'Contact', value:'Contact'}];
    notificationBody;
    notificationStyle;
    notificationTitle;

    set results(value) {
        console.log('getMergeGroups wire');
        console.log(JSON.stringify(value));
        this.rows = typeof value !== 'undefined' && value != null && value.length > 0 ? JSON.parse(JSON.stringify(value)) : null;
        this.fetchCount();
    }
    get results(){
        return this.rows;
    }
    connectedCallback(){
        var objectisNull = this.objectType == null || this.objectType === undefined;
        this.limitAmt = this.limitAmt == null || this.limitAmt === undefined ? 100 : Number(this.limitAmt);
        this.offsetAmt = this.offsetAmt == null ||this.offsetAmt === undefined ? 0 : this.offsetAmt;
        this.objectType = objectisNull ? 'Contact' : this.objectType;
        if(objectisNull){
            this.fetchRules();
        }
    }
    @wire(getMergeGroups, {objectType:'$objectType',ruleName:'$rule',limitAmt:'$limitAmt',offsetAmt:'$offsetAmt'})
        getRowData({error, data}) {
            if(data){
                this.results = data;
                this.rows = JSON.parse(JSON.stringify(data));
            } else if(error){
                this.rows=undefined;
                this.results = undefined;
                this.error=error;
                this.handleError();
            }
        }

   fetchCount(){
    getCount({objectType:this.objectType,ruleName:this.rule})
        .then(result=>{
            this.countValue = result;
        })
        .catch(error=>{
            this.countValue = undefined;
            this.error=result.error;
            this.handleError();           
        })
   } 
    fetchRules(){
        getDuplicateRules({objectType:this.objectType})
            .then(result=>{
                this.rules = result;
            })
            .catch(error=>{
                this.error=error;
                this.handleError();
            })
    }   
    handleSuccess() {
        console.log('handleSuccess called');
        this.notificationTitle = 'Record Saved';
        this.notificationStyle='success';
        this.showNotification();
        this.refresh();
    }

    handleError() {
        this.notificationTitle = 'An error has occurred';
        this.notificationBody = 'Unknown error';
        this.notificationStyle = 'error';
        if(Array.isArray(this.error.body)) {
            this.notificationBody = this.error.body.map(e => e.message).join(', ');
        } else if(typeof this.error.body.message === 'string') {
            this.notificationBody = this.error.body.message;
        }
        this.showNotification();
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
        console.log('handlePager');
        console.log(JSON.stringify(event.detail));
        this.currentPage = Number(event.detail);
        this.offsetAmt = Number((this.currentPage - 1) * Number(this.limitAmt));
    }
    showNotification(){
        this.dispatchEvent(
            new ShowToastEvent({
                title: this.notificationTitle,
                message: this.notificationBody,
                variant: this.notificationStyle
            })
        );
    }

}