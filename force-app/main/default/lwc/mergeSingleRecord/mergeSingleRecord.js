import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getObjectFields from '@salesforce/apex/MRG_MergeSettings_CTRL.getObjectFields';
import getReadableObjectFields from '@salesforce/apex/MRG_MergeSettings_CTRL.getReadableObjectFields';

export default class mergeSingleRecord extends LightningElement {
    @api set record(value) {
        this.mergeRecord = JSON.parse(JSON.stringify(value));
        this.objectType = this.mergeRecord.objectName;
        this.isEdit = this.mergeRecord !== undefined && this.mergeRecord != null && this.mergeRecord.name.includes('TEMP');
        // field metadata is only needed in edit mode; loading it lazily keeps read-mode rows cheap
        if(this.isEdit) {
            this.fieldsObjectType = this.objectType;
        }
        // Advanced opens automatically for an advanced rule; Filter Logic expands if it has a value
        this.advancedOpen = this.isAdvancedRule;
        this.activeTab = this.firstTabKey;
        this.filterLogicOpen = !!(this.mergeRecord && this.mergeRecord.filterLogic);
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
    // the objectType the field wires load for; undefined until the row enters edit mode so
    // read-mode rows never fetch or process the (large) object field describes (#89)
    @track fieldsObjectType;
    advancedOpen = false;
    filterLogicOpen = false;
    activeTab = 'fallback';
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
    // 'Combine Values' is appended only when the selected field is a multi-select picklist
    get ruleOptions() {
        const options = [
            {label:'Oldest Record',value:'Oldest'},
            {label:'Newest Record',value:'Newest'},
            {label:'Largest Field Value',value:'Largest'},
            {label:'Smallest Field Value',value:'Smallest'},
            {label:'Longest Text Value',value:'Longest'},
            {label:'Shortest Text Value',value:'Shortest'},
            {label:'Contains Text',value:'Contains'},
            {label:'Related Field Value',value:'Related Field'},
            {label:'Complex Rule',value:'Complex'},
            {label:'Apex Defined Rule',value:'Apex Defined'}
        ];
        if(this.isMultiPicklistField){
            options.push({label:'Combine Values',value:'Combine'});
        }
        if(this.isConcatenatableField || (this.mergeRecord != null && this.mergeRecord.rule === 'Concatenate')){
            options.push({label:'Concatenate',value:'Concatenate'});
        }
        return options;
    }
    get isMultiPicklistField() {
        return this.mergeRecord != null && this.mergeRecord.fieldName != null
            && this.fieldTypeByName[this.mergeRecord.fieldName] === 'MULTIPICKLIST';
    }
    // Concatenate applies to free-text field types and multi-select picklists
    get isConcatenatableField() {
        if(this.mergeRecord == null || this.mergeRecord.fieldName == null){
            return false;
        }
        const fieldType = this.fieldTypeByName[this.mergeRecord.fieldName];
        return ['STRING','TEXTAREA','EMAIL','PHONE','URL','MULTIPICKLIST'].includes(fieldType);
    }
    tieBreakRuleOptions = [{label:'(none)',value:''},{label:'Oldest',value:'Oldest'},{label:'Newest',value:'Newest'},{label:'Largest',value:'Largest'},{label:'Smallest',value:'Smallest'},{label:'Longest',value:'Longest'},{label:'Shortest',value:'Shortest'}];
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

    get isConcatenate(){
        return this.mergeRecord !== undefined && this.mergeRecord != null && this.preserve && this.mergeRecord.rule == 'Concatenate';
    }

    // the character shown in the Concatenate tab: multiselects are locked to ';'
    get concatenateCharacterValue(){
        if(this.isMultiPicklistField){
            return ';';
        }
        return (this.mergeRecord && this.mergeRecord.concatenateCharacter) || ';';
    }

    // rules that need configuration beyond the simple ones -> auto-open the Advanced section
    get isAdvancedRule(){
        return this.isRelatedField || this.isContains || this.isComplex || this.isApex || this.isConcatenate;
    }
    // Advanced (incl. the always-present Fallback tab) is available once an object is chosen
    get showAdvanced(){
        return this.objectType != null && this.objectType !== '';
    }
    get advancedChevron(){
        return this.advancedOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }
    get filterLogicChevron(){
        return this.filterLogicOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }
    // the first (default-active) tab for the current rule
    get firstTabKey(){
        if(this.isRelatedField) return 'related';
        if(this.isContains) return 'contains';
        if(this.isComplex) return 'ruleDef';
        if(this.isApex) return 'apex';
        if(this.isConcatenate) return 'concat';
        return 'fallback';
    }
    // nav tabs: the rule-specific tab(s) first, Fallback Field always last
    get tabs(){
        const t = [];
        if(this.isRelatedField) t.push({key:'related', label:'Related Field'});
        else if(this.isContains) t.push({key:'contains', label:'Contains Value'});
        else if(this.isComplex){ t.push({key:'ruleDef', label:'Rule Definition'}); t.push({key:'tieBreak', label:'Tie-Break'}); }
        else if(this.isApex) t.push({key:'apex', label:'Apex Class'});
        else if(this.isConcatenate) t.push({key:'concat', label:'Concatenate Character'});
        t.push({key:'fallback', label:'Fallback Field'});
        return t.map(tab=>({
            key: tab.key,
            label: tab.label,
            liClass: 'slds-tabs_default__item' + (tab.key === this.activeTab ? ' slds-is-active' : '')
        }));
    }
    // per-panel visibility classes (all panels for the rule render; only the active one is shown)
    get panelClass(){
        const cls = key => 'slds-tabs_default__content slds-p-around_small ' + (this.activeTab === key ? 'slds-show' : 'slds-hide');
        return {
            related: cls('related'),
            contains: cls('contains'),
            ruleDef: cls('ruleDef'),
            tieBreak: cls('tieBreak'),
            apex: cls('apex'),
            concat: cls('concat'),
            fallback: cls('fallback')
        };
    }
    toggleAdvanced(){
        this.advancedOpen = !this.advancedOpen;
    }
    toggleFilterLogic(){
        this.filterLogicOpen = !this.filterLogicOpen;
    }
    selectTab(event){
        this.activeTab = event.currentTarget.dataset.tab;
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
    
    @wire(getObjectFields, {objectType:'$fieldsObjectType'})
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
    @wire(getReadableObjectFields, {objectType:'$fieldsObjectType'})
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
        this.fieldsObjectType = this.objectType;
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
        if(this.mergeRecord.rule === 'Concatenate'){
            // multiselects are locked to ';'; otherwise keep any configured character
            this.mergeRecord.concatenateCharacter = this.isMultiPicklistField ? ';' : (this.mergeRecord.concatenateCharacter || ';');
        }
        if(this.mergeRecord.rule === 'Complex'){
            this.mergeRecord.conditions = Array.isArray(this.mergeRecord.conditions) ? this.mergeRecord.conditions : [];
            this.mergeRecord.filterLogic = this.mergeRecord.filterLogic || '';
            this.mergeRecord.tieBreakDirection = this.mergeRecord.tieBreakDirection || 'DESC';
            this.refreshConditionInputTypes();
            this.filterLogicOpen = !!this.mergeRecord.filterLogic;
        }
        // choosing an advanced rule opens the Advanced section; move to that rule's first tab
        if(this.isAdvancedRule){
            this.advancedOpen = true;
        }
        this.activeTab = this.firstTabKey;
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

    handleTieBreakRuleSelect(event){
        this.mergeRecord.tieBreakRule = event.detail.value;
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
    handleConcatenateCharacterChange(event){
        this.mergeRecord.concatenateCharacter = event.target.value || ';';
    }
    doEdit(event){
        this.isEdit=true;
        this.fieldsObjectType = this.objectType;
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