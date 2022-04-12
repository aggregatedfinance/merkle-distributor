import { program } from 'commander';
import fs from 'fs';
import { parse } from'csv-parse';

program
  .version('0.0.0')
  .requiredOption(
    '-i, --input <path>',
    'input JSON file location containing a map of account addresses to string balances'
  )

program.parse(process.argv)

parse(fs.readFileSync(program.input, { encoding: 'utf8' }), function(err, records){
    type Output = {
        [key: string]: number
    }
    
    const output : Output = {};

    for (let i = 1; i < records.length; i++) {
        output[records[i][0]] = Number(records[i][1]);
    }

    
    fs.writeFile('test.json', JSON.stringify(output), err => {
        if (err) {
            console.error(err)
        }
    })
  });
