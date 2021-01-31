import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getObjectFields from '@salesforce/apex/CON_MergeSettings_CTRL.getObjectFields';

export default class mergeSingleRecord extends LightningElement {
    @api set record(value) {
        console.log('record set');
        console.log(JSON.stringify(value));
        this.mergeRecord = JSON.parse(JSON.stringify(value));
        this.objectType = this.mergeRecord.objectName;
        this.isEdit = this.mergeRecord !== undefined && this.mergeRecord != null && this.mergeRecord.name.includes('TEMP');
    }   
    get record(){
        return this.mergeRecord;
    }
    @track mergeRecord;
    @api objectType;
    @api modalLabel;
    @track error;
    @track isEdit = false;
    @track action;
    get isActive() {
        return this.record != null && !this.record.disable;
    }
    get preserve() {
        return this.record != null && this.record.type == 'p'; 
    
    }
    get trackingType() {
        var type = this.record != null && this.record.type == 'p' ? 'Preserve' : 'Track';
        return type;
    }
    trackOptions = [{label:'Track Fields',value:'t'},{label:'Preserve Fields',value:'p'}];
    ruleOptions = [{label:'Oldest Record',value:'Oldest'},{label:'Newest Record',value:'Newest'},{label:'Largest Field Value',value:'Largest'},{label:'Smallest Field Value',value:'Smallest'},{label:'Related Field Value',value:'Related Field'}];
    objectOptions = [{label:'Account',value:'Account'},{label:'Contact',value:'Contact'}];
    notificationBody;
    notificationStyle;
    notificationTitle;
    set fieldResults(value) {
        value = value === undefined || value == null ? [] : value;
        var options = [];
        value.forEach(fieldResult=>{
            var option = {};
            option.label = fieldResult.label;
            option.value = fieldResult.name;
            options.push(option);
        })
        this.fieldOptions = options;
    }
    get fieldResults(){
        return this.fieldOptions;
    }
    @track fieldOptions;

    get isRelatedField(){
        return this.mergeRecord !== undefined && this.mergeRecord != null && this.preserve && this.mergeRecord.rule == 'Related Field';
    }

    connectedCallback(){
        this.objectType = this.objectType===undefined || this.objectType == null ? 'Contact' : this.objectType;
    }
    
    @wire(getObjectFields, {objectType:'$objectType'})
        getRowData({error,data}) {
            console.log('wire');
                if(data) {
                    this.fieldOptions = undefined;
                    this.fieldResults = JSON.parse(JSON.stringify(data));
                    this.error=undefined;
                } else if(error){
                    this.fieldResults=undefined;
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
    handleObjectSelect(event) {
        this.objectType = event.detail.value;
        this.mergeRecord.objectName = this.objectType;
    }
    handleFieldSelect(event) {
        this.mergeRecord.fieldName = event.detail.value;
    }
    handleRelatedFieldSelect(event){
        this.mergeRecord.relatedField = event.detail.value;
    }
    handleTypeSelect(event) {
        this.mergeRecord.type = event.detail.value;
        this.mergeRecord.rule = this.mergeRecord.type == 't' ? null : this.mergeRecord.rule;
    }
    handleRuleSelect(event) {
        this.mergeRecord.rule = event.detail.value;
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