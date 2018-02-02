# SynHighlighterEDIFact

A TSynEdit Highlighter for EDIFact messages

* Implements syntax highlighting for EDIFact messages
* Distinguishes between the segment tag, component- and element delimiters, release identifier and segment terminators
* Does not care about correctness of the message but can be configured to only recognize a subset of valid segment tags
* Does not manage message-structure, so can highlight EDIFact messages that are reformated to multiline
* Built in and tested for Delphi XE 10.2.2 only

# Installation

There is no pre-made Delphi package provided, so if you want to install into your IDE to use at designtime you will need to add that yourself. In the absence of that simply add the unit SynHighlighterEDIFact to your uses-list. In an appropriate event-handler like Form.OnCreate create an instance of TSynEDIFactSyn and assign it to your SynEdits and SynMemos. 

# API

The TSynEDIFactSyn class conforms to the common API of syntax-highlighters for the SynEdit suite of components. It has a small number of properties and methods to control its behaviour:

* property CheckValidSegmentTag: boolean - Set to true if you want the component to highlight only segment tags that it recognizes as valid
* procedure AddValidSegmentTag(aTag: string) - Add a new tag to the list of valid tags. There is no API for removing them.
* procedure AddValidSegmentTags(aTags: array of string) - Add a set of new tags to the list of valid tags in one go
* function GetTokenAttributes(aTokenKind: TTokenKind): TSynHighlighterAttributes - Allows access to and changing of the attributes used by the various token types highlighted
