module Plugin

import ParseTree;
import util::IDE;
import rmt::lang::Activities;

void main() {
  registerLanguage("AD", "ad", start[ActivityDef](str src, loc org) {
    return parse(#start[ActivityDef], src, org);
  });
}