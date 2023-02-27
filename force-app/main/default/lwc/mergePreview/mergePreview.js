import { LightningElement,api,wire,track } from 'lwc';
import { subscribe, unsubscribe, onError, setDebugFlag, isEmpEnabled } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPreviewRecord from '@salesforce/apex/MRG_Preview_CTRL.getPreviewRecord';
import { updateRecord } from 'lightning/uiRecordApi';
import OVERRIDE_FIELD from '@salesforce/schema/MergeCandidate__c.Override__c';
import ID_FIELD from '@salesforce/schema/MergeCandidate__c.Id';

export default class mergePreview extends LightningElement {
    @api recordId;

    get recordValue(){
        return this._record;
    }
    set recordValue(value){
        this._record = value;
        if(typeof value === undefined
            || value == null)
            return;
        var _cols = []
        _cols.push('keepRecord');
        _cols.push('mergeRecord1');
        if(value.hasOwnProperty('mergeRecord2'))
            _cols.push('mergeRecord2');
        _cols.push('mergeResultRecord');
        this.cols = _cols;

        var fields = value.hasOwnProperty('fields') && value.fields != null ? value.fields : [];
        this.previewFields = value.hasOwnProperty('previewFields') && value.previewFields != null ? value.previewFields : [];
        this.mergeCandidate = value.mergeCandidate;
        if(value.hasOwnProperty('manualOverrides') && typeof value.manualOverrides !== undefined && value.manualOverrides != null){
            var orMap = new Map();
            value.manualOverrides.forEach(override=>{
                orMap.set(override.fieldName,override.fieldValue);
            })
            this.overrideMap = orMap;
        }
        if(fields.length > 0)
            fields.sort();
        this.rows = fields;
    }
    ignoreFields;
    set previewFields(value){
        var ignoreFields = [];
        if(typeof value === undefined
            || value == null)
            return;
        if(Array.isArray(value)) {
            value.forEach(field=>{
                if(field.hidden)
                    ignoreFields.push(field.fieldName);
            });
        } 
        this.ignoreFields = ignoreFields; 
    }
    _record;
    tablecols;
    notificationBody;
    notificationTitle;
    notificationStyle;
    mergeCandidate;
    @track error;
    @track actionType;
    @track overrideMap = new Map();
    
    set rows(value){
        this._rows = value;
        this.createTableColums();
    }
    get rows(){
        return this._rows;
    }
    _rows;
    @track data;
    @track cols;

    get processed(){
        return typeof this.mergeCandidate !== undefined && this.mergeCandidate != null && this.mergeCandidate.Status__c == 'Processed';
    }

    @wire(getPreviewRecord, {recordId:'$recordId'})
        getRecord({error, data}) {
            if(data){
                this.recordValue = JSON.parse(JSON.stringify(data));
            } else if(error){
                this.recordValue =undefined;
                this.handleError();
            }
        }
    handleSuccess() {
        this.notificationTitle = this.notificationTitle === undefined || this.notificationTitle==null ? 'Record Saved' : this.notificationTitle;
        this.notificationStyle='success';
        this.notificationBody = typeof this.notificationBody === undefined || this.notificationBody == null ? 'Success' : this.notificationBody;
        this.showNotification();
        this.refresh();
    }

    handleError() {
        this.notificationTitle = 'An error has occurred';
        this.notificationBody = 'Unknown error';
        this.notificationStyle = 'error';
        if(typeof this.error === undefined || this.error == null)
            this.error = {};
        if(!this.error.hasOwnProperty('body'))
            this.error.body ={'message':this.notificationBody};
        if(Array.isArray(this.error.body)) {
            this.notificationBody = this.error.body.map(e => e.message).join(', ');
        } else if(this.error.hasOwnProperty('body')
            && this.error.body.hasOwnProperty('message')
            && typeof this.error.body.message === 'string') {
            this.notificationBody = this.error.body.message;
        }
        this.showNotification();
    }
    @track hasData;


    renderedCallback(){
        if(typeof this.data === undefined || this.data == null)
            return;

       this.populatePicklistValues(); 
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
    populatePicklistValues(){
        var table = this.template.querySelector('c-custom-datatable');
        if(typeof table === undefined || table == null)
            return;

        var rows = table.data;
        rows.forEach(row=>{
            if(typeof row.mergeResultRecord === "object"){
                var fieldName = row.fieldname;
                var options = row.mergeResultRecord.picklistOptions;
                var defaultValue = row.mergeResultRecord.picklistValue;
            }
        })

    }
    createTableColums(){
        var columns = [];
        columns = this.cols;
        columns.unshift('fieldname');
        
        var _tablecols = [];
        var keepName = this.mergeCandidate.hasOwnProperty('KeepName__c') ? this.mergeCandidate.KeepName__c : 'Keep Record';
        var merge1Name = this.mergeCandidate.hasOwnProperty('MergeName__c') ? this.mergeCandidate.MergeName__c : 'Merge Record 1';
        var merge2Name = this.mergeCandidate.hasOwnProperty('Merge2Name__c') ? this.mergeCandidate.Merge2Name__c : 'Merge Record 2';
        columns.forEach(col=>{
            var label;

            switch(col) {
                case 'fieldname':
                    label = 'Field';
                    break;
                case 'keepRecord':
                    label = keepName;
                    break;
                case 'mergeRecord1':
                    label = merge1Name;
                    break;
                case 'mergeRecord2':
                    label = merge2Name;
                    break;
                case 'mergeResultRecord':
                    label = 'Merge Result';
                    break;
            }
            var tablecol;
            if(col == 'mergeResultRecord'){
                tablecol = {
                    label : label,
                    fieldName : col,
                    type: 'picklistColumn', 
                    editable: {fieldName: 'editable'}, 
                    typeAttributes: {
                        placeholder: 'Choose value to keep', 
                        options: { fieldName: 'picklistOptions' }, 
                        value: { fieldName: 'picklistValue' }
                    }
                };
            } else {
                tablecol = {
                    label : label,
                    fieldName : col,
                    type: 'text' 
                };
            }
            _tablecols.push(tablecol);
        });
        this.tablecols = _tablecols;
        this.createTableData();
    }
    createTableData(){

        var dataRows = [];

        var columns = [];
        columns = this.cols;
        //columns.unshift('fieldname');

        var keepRecord = this._record.hasOwnProperty('keepRecord') ? this._record.keepRecord : {};
        var mergeRecord1 = this._record.hasOwnProperty('mergeRecord1') ? this._record.mergeRecord1 : {};
        var mergeRecord2 = this._record.hasOwnProperty('mergeRecord2') ? this._record.mergeRecord2 : {};
        var mergeResultRecord = this._record.hasOwnProperty('mergeResultRecord') ? this._record.mergeResultRecord : {};
        var orMap = typeof this.overrideMap === undefined || this.overrideMap == null ?  new Map() : this.overrideMap;
        
        this.rows.forEach(field=>{
            if(!this.ignoreFields.includes(field)){
                var dataRow = {};
                var picklistOptions = [];
                var picklistValue;

                columns.forEach(col=>{
                    var fieldValue = null;
                    var recordObj = {};
                    switch(col) {
                        case 'fieldname':
                            fieldValue = field;
                            break;
                        case 'keepRecord':
                            fieldValue = keepRecord.hasOwnProperty(field) ? keepRecord[field] : null;
                            break;
                        case 'mergeRecord1':
                            fieldValue = mergeRecord1.hasOwnProperty(field) ? mergeRecord1[field] : null;
                            break;
                        case 'mergeRecord2':
                            fieldValue = mergeRecord2.hasOwnProperty(field) ? mergeRecord2[field] : null;
                            break;
                        case 'mergeResultRecord':
                            fieldValue = mergeResultRecord.hasOwnProperty(field) ? mergeResultRecord[field] : null;
                            break;
                    }
                    if(col != 'mergeResultRecord'){
                        if(fieldValue != null && !picklistOptions.includes(fieldValue) && col !='fieldname'){
                            var opt = {};
                            opt.label = fieldValue;
                            opt.value = fieldValue;
                            picklistOptions.push(opt);
                        }
                    } else if(col = 'mergeResultRecord') {
                        var editable = picklistOptions.length > 1;
                        dataRow['editable'] = editable;
                        if(picklistOptions.length > 1){
                            var picklistFieldValue = {};
                            picklistFieldValue.value = fieldValue;
                            picklistFieldValue.options = picklistOptions;
                            picklistFieldValue.placeholder = fieldValue;
                            
                            if(!orMap.has(field)){
                                orMap.set(field,fieldValue);
                            } else {
                                var val = orMap.get(field);
                                picklistFieldValue.value = val;
                                fieldValue = val;
                            }

                            dataRow['picklistOptions'] = picklistFieldValue.options;
                            dataRow['picklistValue'] = picklistFieldValue.value;
                            
                        }
                        
                    }            
                    dataRow[col] = fieldValue;
                });
                dataRows.push(dataRow);
            }
        });
        this.data = dataRows;
        console.log('data');
        console.log(JSON.stringify(dataRows));
        this.hasData=true;
        this.overrideMap = orMap;
    }
    handleSave(event){
        var orMap = new Map();
        var vals = event.detail.draftValues;
        if(typeof vals !== undefined && vals != null){
            vals.forEach(val=>{
                orMap.set(val.fieldname, val.mergeResultRecord);
            })
            this.overrideMap = orMap;
        }
        this.doSave();
    }
    mergeRecord(event){
        this.actionType = 'merge';
        this.doNotify();
    }
    doSave(){
        console.log('doSave called');
        const fields = {};
        var overrideData = [];
        for (let [key, value] of this.overrideMap.entries()) {
            var override = {};
            override.fieldName = key;
            override.fieldValue = value;
            overrideData.push(override);
        }
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[OVERRIDE_FIELD.fieldApiName] = overrideData;
        const recordInput = { fields };
        
        updateRecord(recordInput)
            .then(() => {
                console.log(JSON.stringify(recordInput));
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Merge field overrides saved',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error saving record',
                        message: JSON.stringify(error),
                        variant: 'error'
                    })
                );
            });
    }
    doNotify(){
        const notify = new CustomEvent('notify', {
            bubbles:true,
            composed:false,
            detail:{
                actionType:this.actionType,
                recordId:this.recordValue.recordId
            }
        });
        try {
            this.dispatchEvent(notify);
        } catch (error) {
            this.error = error;
            this.handleError();
        }
    }
}