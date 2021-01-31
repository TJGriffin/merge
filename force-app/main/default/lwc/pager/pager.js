import { LightningElement, api, track } from 'lwc';

export default class Pager extends LightningElement {
    @api get totalPages(){
        return Number(this._totalPages);
    }
    set totalPages(value){
        this._totalPages = Number(value);
        this.checkPager();
    }
    _totalPages;

    @api get currentPage(){
        return Number(this._currentPage);
    }
    set currentPage(value){
        this._currentPage = Number(value);
        this.checkPager();
    }
    _currentPage;

    maxPages = 10;
    @track selectedPage;
    @track pages;
    firstPage;
    pageSets;
    visiblePageSets;

    get showPrevious(){
        return this.firstPage - 1 > 0;
    }
    get showNext(){
        return (this.currentPage + 1) < this.totalPages;
    }
    get showPager(){
        return this.totalPages !== undefined && this.currentPage !== undefined && Number(this.totalPages) > 1;
    }
    get pagerSet(){
        return this.pageSets !== undefined  && this.pageSets != null;
    }

    checkPager(){
        if(this.totalPages !== undefined 
            && this.totalPages != null 
            && this.currentPage !== undefined 
            && this.currentPage != null) {
            this.setPager();
        }
    }

    setPager(){
        var pages = [];
        this.pageSets = Number(Math.ceil(Number(this.totalPages)/this.maxPages));
        this.currentPageSet = Number(Math.ceil(Number(this.currentPage)/this.maxPages));
        this.firstPageInSet = Number(((this.currentPageSet * this.maxPages) - this.maxPages) + 1);
        this.visiblePageSets = this.firstPageInSet + this.maxPages > this.totalPages ? Number(this.totalPages) : Number(this.firstPageInSet + this.maxPages);
        for(var i=this.firstPageInSet; i <= this.visiblePageSets; i++){
            var page = {};
            page.value=i;
            page.label=i;
            page.isCurrentPage = i == this.currentPage;
            pages.push(page);
        }
        this.pages = pages;
        console.log('pages');
        console.log('maxPages:'+this.maxPages);
        console.log('currentPage:'+this.currentPage);
        console.log('totalPages:'+this.totalPages);
        console.log('firstPageInSet:'+this.firstPageInSet);
        console.log('pageSets:'+this.pageSets);
        console.log('currentPageSet:'+this.currentPageSet);
        console.log('visiblePageSets:'+this.visiblePageSets);
        console.log('showPager:'+this.showPager);
        console.log(JSON.stringify(this.pages));
    }

    handlePageSelect(event){
        this.selectedPage = Number(event.target.value);
        this.currentPage = this.selectedPage;
        this.doNotify();
    }

    handleNext(event){
        this.selectedPage = Number(this.currentPage)+1;
        this.doNotify();
    }
    handlePrev(event){
        this.selectedPage = Number(this.currentPage)-1;
        this.doNotify();
    }

    doNotify(){
        const selectPage = new CustomEvent('page', {
            bubbles:true,
            composed:false,
            detail:this.selectedPage
        });
        this.dispatchEvent(selectPage);
    }

}