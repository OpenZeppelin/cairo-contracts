import fs from "fs/promises";
import * as core from "@actions/core";

const classHashesFilePath = "docs/modules/ROOT/pages/utils/_class_hashes.adoc";

async function main() {
  const compilerVersionInput = core.getInput("compiler-version");
  const jsonFileInput = core.getInput("json-file");

  let content = await fs.readFile(jsonFileInput, 'utf8');

  // Remove the first 4 lines
  // TODO: Fix the output of the class hashes to not include the first 4 lines
  let json = content.split('\n').slice(4).join('\n');
  let hashes = JSON.parse(json);

  let newContent = createHashesFileNewContent(hashes.contracts, compilerVersionInput);
  await fs.writeFile(classHashesFilePath, newContent);
}

function createHashesFileNewContent(contracts, cairoVersion) {
    const header = `// Eric Version\n:class-hash-cairo-version: \
          https://crates.io/crates/cairo-lang-compiler/${cairoVersion}[cairo ${cairoVersion}]`;

    let hashes = "// Class Hashes\n";
    // The slice 13 is to remove the "openzeppelin_" prefix
    hashes += contracts.sort(compareContracts).map(contract => {
        return `:${contract.name.slice(13)}: ${contract.sierra}`;
    }).join('\n');

    const footer = "// Presets page\n\
          :presets-page: xref:presets.adoc[Compiled class hash]";

    return `${header}\n\n${hashes}\n\n${footer}`;
}

function compareContracts( first, second ) {
  if ( first.name < second.name ){
    return -1;
  } else if ( first.name > second.name ){
    return 1;
  } else {
    return 0;
  }
}

main();