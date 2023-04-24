import React from 'react'
import ReactDOM from 'react-dom'
import PropTypes from 'prop-types'
import FormTesting from '../components/FormTesting'

document.addEventListener('DOMContentLoaded', () => {
  ReactDOM.render(
    <FormTesting/>,
    document.body.appendChild(document.createElement('div')),
  )
})
