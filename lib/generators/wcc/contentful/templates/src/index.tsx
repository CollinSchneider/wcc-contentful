import * as contentfulExtension from 'contentful-ui-extensions-sdk'
import {IContentfulExtensionSdk} from 'contentful-ui-extensions-sdk'
import {h, render, Component} from 'preact'

declare function require(module: string): any;
const styles = require('./index.scss')

contentfulExtension.init((extension) => {
  render(<App {...extension} />,
    document.getElementById('react-root'))
})

class App extends Component<IContentfulExtensionSdk, {}> {

  render() {
    return <div id="app">
      <h1>It works!</h1>
    </div>
  }
}