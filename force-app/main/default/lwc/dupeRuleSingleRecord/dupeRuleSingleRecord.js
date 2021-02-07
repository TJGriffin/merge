import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveRules from '@salesforce/apex/MRG_DupeSettings_CTRL.getActiveDuplicateRules';

export default class DupeRuleSingleRecord extends LightningElement {
    @api set record(value) {
        this.mergeRecord = JSON.parse(JSON.stringify(value));
        this.objectType = this.mergeRecord.objectType;
        this.isEdit = this.mergeRecord !== undefined && this.mergeRecord != null && this.mergeRecord.name.includes('TEMP');
        this.autoMerge = this.mergeRecord !== undefined && this.mergeRecord != null && this.mergeRecord.hasOwnProperty('autoMerge') ? this.mergeRecord.autoMerge : false;
    }   
    get record(){
        return this.mergeRecord;
    }
    get activeDuplicateRules(){
        var ruleOptions = [];
        if(this.dupeRules != null
            && typeof this.dupeRules !== 'undefined'
            && this.dupeRules.length > 0) {
            console.log('get activeDuplicateRules');
            console.log(JSON.stringify(this.dupeRules));
            this.dupeRules.forEach(result=>{
                ruleOptions.push({label:result.name, value:result.name});
            })
        }
        return ruleOptions;     
    }
    @track mergeRecord;
    @api objectType;
    @api modalLabel;
    @track dupeRule;
    @track dupeRules;
    @track error;
    @track autoMerge = false;
    @track isEdit = false;
    @track action;
    get isActive() {
        return true;
    }
    objectOptions = [{label:'Account',value:'Account'},{label:'Contact',value:'Contact'}];
    notificationBody;
    notificationStyle;
    notificationTitle;

    connectedCallback(){
        this.objectType = this.objectType===undefined || this.objectType == null ? 'Contact' : this.objectType;
        this.dupeRule = this.record != null && this.record.hasOwnProperty('name') ? this.record.name : this.dupeRule;
    }
    @wire(getActiveRules)
        getRowData({error,data}) {
            if(data) {
                console.log('wire has data');
                console.log(JSON.stringify(data));
                this.dupeRules = JSON.parse(JSON.stringify(data));
                this.error=undefined;
            } else if(error){
                this.dupeRules=undefined;
                this.error=error;
                this.handleError();
            }
        }
        
    handleCancel(event) {
        this.isEdit=false;
        this.action='cancel';
        this.doNotify();
    }  
    handleSave(event) {
        this.isEdit=false;
        this.action='save';
        this.doNotify();
    }
    handleAutoMerge(event) {
        console.log(JSON.stringify(event.target.checked));
        this.autoMerge = event.target.checked;
        this.mergeRecord.autoMerge = this.autoMerge;
    }

    handleDupeRuleSelect(event) {
        this.mergeRecord.name = event.detail.value;
        this.dupeRule = this.mergeRecord.name;
        this.mergeRecord.ruleName = this.dupeRule;
        this.dupeRules.forEach(rule=>{
            if(rule.name==event.detail.value){
                this.objectType = rule.objectType;
                this.mergeRecord.objectType = this.objectType;
            }
        })
    }
    doEdit(event){
        this.isEdit=true;
    }
    doDisable(event) {
        this.record.disable=true;
        this.isEdit=false;
        this.action='save';
        this.doNotify();
    }
    doEnable(event) {
        this.record.disable=false;
        this.isEdit=false;
        this.action='save';
        this.doNotify();
    }
    doNotify(){
        console.log('do notify');
        console.log(JSON.stringify(this.record));
        this.isEdit=false;
        this.record.name = this.record.name == null ? this.record.fieldName+''+this.record.objectName : this.record.name;
        const notify = new CustomEvent('notify', {
            bubbles:true,
            composed:false,
            detail:{
                actionType:this.action,
                recordValue:this.record
            }
        });
        try {
            this.dispatchEvent(notify);
        } catch (error) {
            this.error = error;
            this.handleError();
        }
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