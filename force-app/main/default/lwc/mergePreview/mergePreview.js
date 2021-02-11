import { LightningElement,api,wire,track } from 'lwc';
import { subscribe, unsubscribe, onError, setDebugFlag, isEmpEnabled } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPreviewRecord from '@salesforce/apex/MRG_Preview_CTRL.getPreviewRecord';

export default class mergePreview extends LightningElement {
    @api recordId;

    get recordValue(){
        return this._record;
    }
    set recordValue(value){
        console.log('set record');
        console.log(JSON.stringify(value));
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
        var fields = value.fields;
        this.mergeCandidate = value.mergeCandidate;
        fields.sort();
        this.rows = fields;
    }

    _record;
    tablecols;
    notificationBody;
    notificationTitle;
    notificationStyle;
    mergeCandidate;
    @track error;
    @track actionType;
    
    set rows(value){
        console.log('set rows');
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

    showNotification(){
        this.dispatchEvent(
            new ShowToastEvent({
                title: this.notificationTitle,
                message: this.notificationBody,
                variant: this.notificationStyle
            })
        );
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
            var tablecol = {
                label : label,
                fieldName : col,
                type: 'text' 
            };
            _tablecols.push(tablecol);
        });
        this.tablecols = _tablecols;
        this.createTableData();
    }
    createTableData(){

        var dataRows = [];

        var columns = [];
        columns = this.cols;
        columns.unshift('fieldname');

        var keepRecord = this._record.hasOwnProperty('keepRecord') ? this._record.keepRecord : {};
        var mergeRecord1 = this._record.hasOwnProperty('mergeRecord1') ? this._record.mergeRecord1 : {};
        var mergeRecord2 = this._record.hasOwnProperty('mergeRecord2') ? this._record.mergeRecord2 : {};
        var mergeResultRecord = this._record.hasOwnProperty('mergeResultRecord') ? this._record.mergeResultRecord : {};
        
        this.rows.forEach(field=>{
            var dataRow = {};
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
                dataRow[col] = fieldValue;
            });
            dataRows.push(dataRow);
        });
        this.data = dataRows;
        this.hasData=true;
    }

    mergeRecord(event){
        this.actionType = 'merge';
        this.doNotify();
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