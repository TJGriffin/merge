import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getObjectFields from '@salesforce/apex/MRG_MergeSettings_CTRL.getObjectFields';
import getReadableObjectFields from '@salesforce/apex/MRG_MergeSettings_CTRL.getReadableObjectFields';

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
    @api usedFields;
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
    ruleOptions = [{label:'Oldest Record',value:'Oldest'},{label:'Newest Record',value:'Newest'},{label:'Largest Field Value',value:'Largest'},{label:'Smallest Field Value',value:'Smallest'},{label:'Longest Text Value',value:'Longest'},{label:'Shortest Text Value',value:'Shortest'},{label:'Contains Text',value:'Contains'},{label:'Related Field Value',value:'Related Field'},{label:'Complex Rule',value:'Complex'},{label:'Apex Defined Rule',value:'Apex Defined'}];
    operatorOptions = [
        {label:'equals',value:'equals'},
        {label:'not equals',value:'notEquals'},
        {label:'less than',value:'lessThan'},
        {label:'less or equal',value:'lessOrEqual'},
        {label:'greater than',value:'greaterThan'},
        {label:'greater or equal',value:'greaterOrEqual'},
        {label:'contains',value:'contains'},
        {label:'starts with',value:'startsWith'},
        {label:'ends with',value:'endsWith'}
    ];
    directionOptions = [{label:'Descending',value:'DESC'},{label:'Ascending',value:'ASC'}];
    objectOptions = [{label:'Account',value:'Account'},{label:'Contact',value:'Contact'}];
    fieldTypeByName = {};
    notificationBody;
    notificationStyle;
    notificationTitle;
    set fieldResults(value) {
        value = value === undefined || value == null ? [] : value;
        var options = [];
        var relatedFieldOptions = [];
        value.forEach(fieldResult=>{
                var option = {};
                option.label = fieldResult.label;
                option.value = fieldResult.name;
            if(!this.usedFields.includes(fieldResult.name)) {
                options.push(option);
            } else {
                relatedFieldOptions.push(option);
            }
        })
        this.fieldOptions = options;
        this.relatedFieldOptions = relatedFieldOptions;
    }
    get fieldResults(){
        return this.fieldOptions;
    }
    set relatedFieldResults(value){
        
    }
    get relatedFieldResults(){
        return this.relatedFieldOptions;
    }
    @track relatedFieldOptions;
    @track fieldOptions;
    @track allFieldOptions = [];

    get isRelatedField(){
        return this.mergeRecord !== undefined && this.mergeRecord != null && this.preserve && this.mergeRecord.rule == 'Related Field';
    }

    get isComplex(){
        return this.mergeRecord !== undefined && this.mergeRecord != null && this.preserve && this.mergeRecord.rule == 'Complex';
    }

    get isApex(){
        return this.mergeRecord !== undefined && this.mergeRecord != null && this.preserve && this.mergeRecord.rule == 'Apex Defined';
    }

    get isContains(){
        return this.mergeRecord !== undefined && this.mergeRecord != null && this.preserve && this.mergeRecord.rule == 'Contains';
    }

    // re-derive each condition's value input type from its selected field, and add row indices
    refreshConditionInputTypes(){
        if(this.mergeRecord && Array.isArray(this.mergeRecord.conditions)){
            this.mergeRecord.conditions = this.mergeRecord.conditions.map((c, i)=>{
                const type = this.fieldTypeByName[c.fieldName];
                c.inputType = this.inputTypeForFieldType(type);
                c.isCheckbox = c.inputType === 'checkbox';
                c.checked = c.isCheckbox && c.value === 'true';
                c.conditionIndex = i;
                return c;
            });
        }
    }

    inputTypeForFieldType(fieldType){
        switch(fieldType){
            case 'BOOLEAN': return 'checkbox';
            case 'DATE': return 'date';
            case 'DATETIME': return 'datetime';
            case 'DOUBLE':
            case 'CURRENCY':
            case 'INTEGER':
            case 'LONG':
            case 'PERCENT': return 'number';
            default: return 'text';
        }
    }

    connectedCallback(){
        this.objectType = this.objectType===undefined || this.objectType == null ? 'Contact' : this.objectType;
    }
    
    @wire(getObjectFields, {objectType:'$objectType'})
        getRowData({error,data}) {
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
    // readable fields (incl. read-only like CreatedDate) for the complex condition + tie-break pickers,
    // which only READ values to select a record
    @wire(getReadableObjectFields, {objectType:'$objectType'})
        getReadableRowData({error,data}) {
                if(data) {
                    var allOptions = [];
                    var typeMap = {};
                    data.forEach(f=>{
                        allOptions.push({ label: f.label, value: f.name });
                        typeMap[f.name] = f.type;
                    });
                    this.allFieldOptions = allOptions;
                    this.fieldTypeByName = typeMap;
                    this.refreshConditionInputTypes();
                } else if(error){
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
    handleFallbackFieldSelect(event){
        this.mergeRecord.fallbackField = event.detail.value;
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
        if(this.mergeRecord.rule === 'Complex'){
            this.mergeRecord.conditions = Array.isArray(this.mergeRecord.conditions) ? this.mergeRecord.conditions : [];
            this.mergeRecord.filterLogic = this.mergeRecord.filterLogic || '';
            this.mergeRecord.tieBreakDirection = this.mergeRecord.tieBreakDirection || 'DESC';
            this.refreshConditionInputTypes();
        }
    }

    addCondition(){
        const conditions = Array.isArray(this.mergeRecord.conditions) ? [...this.mergeRecord.conditions] : [];
        conditions.push({ fieldName:'', operator:'equals', value:'' });
        this.mergeRecord.conditions = conditions;
        this.refreshConditionInputTypes();
    }

    removeCondition(event){
        const ci = parseInt(event.target.dataset.condition, 10);
        const conditions = [...this.mergeRecord.conditions];
        conditions.splice(ci, 1);
        this.mergeRecord.conditions = conditions;
        this.refreshConditionInputTypes();
    }

    handleConditionFieldSelect(event){
        const ci = parseInt(event.target.dataset.condition, 10);
        this.mergeRecord.conditions[ci].fieldName = event.detail.value;
        this.refreshConditionInputTypes();
    }

    handleConditionOperatorSelect(event){
        const ci = parseInt(event.target.dataset.condition, 10);
        this.mergeRecord.conditions[ci].operator = event.detail.value;
    }

    handleConditionValueChange(event){
        const ci = parseInt(event.target.dataset.condition, 10);
        const cond = this.mergeRecord.conditions[ci];
        cond.value = cond.isCheckbox ? String(event.target.checked) : event.target.value;
    }

    handleTieBreakFieldSelect(event){
        this.mergeRecord.tieBreakField = event.detail.value;
    }

    handleTieBreakDirectionSelect(event){
        this.mergeRecord.tieBreakDirection = event.detail.value;
    }

    handleFilterLogicChange(event){
        this.mergeRecord.filterLogic = event.target.value;
    }
    handleApexClassChange(event){
        this.mergeRecord.apexClass = event.target.value;
    }
    handleContainsValueChange(event){
        this.mergeRecord.containsValue = event.target.value;
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
        this.isEdit=false;
        this.record.name = this.record.name == null ? this.record.fieldName+''+this.record.objectName : this.record.name;
        // strip UI-only keys from complex conditions so the saved JSON matches the Apex condition shape
        if(Array.isArray(this.record.conditions)){
            this.record.conditions = this.record.conditions.map(c=>({
                fieldName: c.fieldName,
                operator: c.operator,
                value: c.value
            }));
        }
        console.log(JSON.stringify(this.record));
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