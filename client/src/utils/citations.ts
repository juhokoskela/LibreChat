export const SPAN_REGEX = /(\\ue203.*?\\ue204)/g;
export const COMPOSITE_REGEX = /(\\ue200.*?\\ue201)/g;
export const STANDALONE_PATTERN = /\\ue202turn(\d+)(search|image|news|video|ref|file)(\d+)/g;
export const CITE_PATTERN = /cite(turn\d+)(search|image|news|video|ref|file)(\d+)/g;
export const SIMPLE_TURN_PATTERN = /(turn\d+)(search|image|news|video|ref|file)(\d+)/g;
export const CLEANUP_REGEX = /\\ue200|\\ue201|\\ue202|\\ue203|\\ue204|\\ue206|cite|turn/g;
export const INVALID_CITATION_REGEX = /\s*\\ue202turn\d+(search|news|image|video|ref|file)\d+/g;
