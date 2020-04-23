# serve

A simple file server
- Compression
- Customizable port
- Exclude files
- Optional listing of directories
- CORS

## Installation

TODO: Write installation instructions here

## Usage

Just run the executable with the directory with the cirectory to host<br>
`serve ~/path/to/files/`<br>
add `-x` for compression<br>
add `-c` for CORS support<br>
add `-d` to NOT list directories<br>
add `-p <someport>` to host the files on a specific port<br>
add `-e <filetypes>` to exclude those files<br>

Default port: `8080`<br>
A directory does not need to be specified, it will default to the current directory<br>

E.g.: `serve -x -c -p 1234 -e png,jpg,gif`



## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/data-niklas/serve/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Niklas Loeser](https://github.com/data-niklas) - creator and maintainer
