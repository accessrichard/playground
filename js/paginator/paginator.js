/**
 * 2013-11-16 Richard Kanavati
 * Simple bootstrap jQuery pagination plugin. 
 * version 0.1
 */
(function ($) {
    /*jslint maxlen: 130*/
    /*global document, window*/

    var Paginate = this.Paginate = function (element, options) {
        this.domNode = element;        
        this.settings = $.extend({}, this.defaults, options);
        this.settings.number = parseInt(this.settings.number, 10);
        this.settings.limit = parseInt(this.settings.limit, 10);
        this.settings.defaultLimit = parseInt(this.settings.defaultLimit, 10);
        this.settings.beginRange = parseInt(this.settings.beginRange, 10);
        this.settings.endRange = parseInt(this.settings.endRange, 10);
        this.init();
        return this;
    };

    Paginate.prototype = {

        defaults: {
            displayCount: 10,
            showSummary: true,
            summaryNode: '.log-summary',
            pageLimit: 10,
            number: 1,
            pageSizes: [10, 25, 50, 100, 250, 500],
            beginRange: 0,
            endRange: 10,
            defaultLimit: 10,
            displayChars: { firstPage: '&laquo;', prevPage: '&lsaquo;', lastPage: '&raquo;', nextPage: '&rsaquo;' }
        },

        init: function () {
            var s = this.settings;
            if (s.total >= s.limit) {
                this.drawPagination();
            } else {
                $(this.domNode).html("");
            }

            if (this.settings.showSummary) {
                this.displayLogSummary();
            }

            if (typeof s.onRecordCountSelectionChange === 'function' && s.total >= s.defaultLimit) {
                this.displayRecordCountSelection(s.pageSizes);
            }

        },

        getPageRanges: function () {

            var range = {},
                s = this.settings;

            range.minPage = 1;
            range.maxPage = Math.ceil(s.total / s.limit);

            range.minDisplayRange = Math.max(range.minPage, s.number - Math.ceil(s.displayCount / 2));
            range.maxDisplayRange = Math.min(range.maxPage, range.minDisplayRange + s.displayCount - 1);

            if (range.maxDisplayRange - range.minDisplayRange < s.displayCount - 1) {
                range.minDisplayRange = Math.max(range.maxDisplayRange - s.displayCount - 1, range.minPage);
            }

            return range;
        },

        drawPagination: function () {
            $(this.domNode).html("");
            var range = this.getPageRanges(),
                s = this.settings,
                activePage,
                i,
                ul = $(this.domNode),
                disableMax,
                disableMin = s.number <= range.minPage ? "disabled" : "";

            this.addPageLink(ul, range.minPage, disableMin, s.displayChars.firstPage, disableMin === "");
            this.addPageLink(ul, s.number - 1, disableMin, s.displayChars.prevPage, disableMin === "");

            if (s.total > s.limit) {

                for (i = range.minDisplayRange; i <= range.maxDisplayRange; i += 1) {
                    activePage = i === s.number ? "active" : "";
                    this.addPageLink(ul, i, activePage, i, activePage === "");
                }

            }

            disableMax = s.number >= range.maxDisplayRange ? "disabled" : "";
            this.addPageLink(ul, s.number + 1, disableMax, s.displayChars.nextPage, disableMax === "");
            this.addPageLink(ul, range.maxPage, disableMax, s.displayChars.lastPage, disableMax === "");
            
        },

        addPageLink: function (node, number, cls, text, addOnClick) {

            var li = $("<li></li>"),
                a = $("<a></a>")
                    .attr('href', '#')
                    .append(text);

            if (addOnClick) {
                a.on('click', null, { number: number }, this.settings.onPageClickEvent);
            } else {
                a.on('click', function (e) {
                    e.preventDefault();
                });
            }

            if (cls && cls.length > 0) {
                li.addClass(cls);
            }

            node.append(li.append(a));
        },

        displayLogSummary: function () {
            var endRange = this.settings.endRange > this.settings.total ? this.settings.total : this.settings.endRange;
            $(this.settings.summaryNode)
                .text('Showing records (' +
                    this.settings.beginRange + " - " + endRange +
                    ' ) of (' + this.settings.total + ') Records.');
        },

        displayRecordCountSelection: function (selections) {

            var $lastLi,
                node = this.domNode,
                select = $('<select></select>)').addClass('form-control width-pagination'),
                li = $('<li></li>');

            $.each(selections, function () {
                select.append($('<option></option>').attr('value', this).html('Show ' + this + ' records.'));
            });

            li.append(select.on('change', this.settings.onRecordCountSelectionChange));

            $lastLi = $(node).find('li:last');
            if ($lastLi.length > 0) {
                $lastLi.after(li);
            } else {
                node.append(li);
            }
            node.find('select').val(this.settings.limit);
        }
    };

    $.fn.paginate = function (options) {
        /*jshint unused: false*/
        var jsLintSuppression = new Paginate(this, options);
        /*jshint unused: true*/
        return this;
    };

}(window.jQuery));