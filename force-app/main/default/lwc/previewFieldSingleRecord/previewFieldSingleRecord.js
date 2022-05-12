import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getObjectFields from '@salesforce/apex/MRG_MergeSettings_CTRL.getObjectFields';

export default class previewFieldSingleRecord extends LightningElement {
    @api set record(value) {
        this.previewField = JSON.parse(JSON.stringify(value));
        this.objectType = this.previewField.objectName;
        this.isEdit = this.previewField !== undefined && this.previewField != null && this.previewField.name.includes('TEMP');
    }   
    get record(){
        return this.previewField;
    }
    @track previewField;
    @api objectType;
    @api modalLabel;
    @track error;
    @track isEdit = false;
    @track action;
    get isHidden() {
        return this.record != null && this.record.hidden;
    }

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
        this.previewField.objectName = this.objectType;
    }
    handleFieldSelect(event) {
        this.previewField.fieldName = event.detail.value;
    }

    doEdit(event){
        this.isEdit=true;
    }
    doHide(event) {
        this.record.hidden=true;
        this.isEdit=false;
        this.action='save';
        this.doNotify();
    }
    doShow(event) {
        this.record.hidden=false;
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