import { LightningElement,api,wire,track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPreviewRecord from '@salesforce/apex/MRG_Preview_CTRL.getPreviewRecord';

export default class FieldTracking extends LightningElement {
    columns =[
        {
            label : 'Field Name',
            fieldName : 'MergeValueType__c'
        },
        {
            label : 'Keep Record Id',
            fieldName : 'KeptRecordId__c'
        },
        {
            label : 'Kept Value',
            fieldName : 'KeptValue__c'
        },
        {
            label : 'Merge Record Id',
            fieldName : 'MergedRecordId__c'
        },
        {
            label : 'Merged Value',
            fieldName : 'MergeValue__c'
        },
    ];
    @api recordId;
    get recordValue(){
        return this._record;
    }
    set recordValue(value){
        this._record = value;
        this.rows = value.fieldHistory;
        console.log(JSON.stringify(this.rows));
        this.cols = this.columns;
        this.hasData=true;
    }
    _record;   

    @track rows;
    @track cols;
    get hasRows(){
        return typeof this.rows !== undefined && this.rows != null && this.rows.length > 0;
    }
    @track hasData;
    @wire(getPreviewRecord, {recordId:'$recordId'})
        getRecord({error, data}) {
            if(data){
                this.recordValue = data;
            } else if(error){
                this.recordValue =undefined;
                this.handleError();
            }
        }

}