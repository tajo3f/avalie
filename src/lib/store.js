import { demoData } from '../data/mock.js'

const DATA_KEY = 'tajo-avalia-demo-data-v1'
const SESSION_KEY = 'tajo-avalia-session-v1'

function clone(value) { return JSON.parse(JSON.stringify(value)) }

export function loadData() {
  try {
    return JSON.parse(localStorage.getItem(DATA_KEY)) || clone(demoData)
  } catch {
    return clone(demoData)
  }
}

export function saveData(data) {
  localStorage.setItem(DATA_KEY, JSON.stringify(data))
  window.dispatchEvent(new CustomEvent('tajo:data'))
}

export function resetDemo() {
  localStorage.setItem(DATA_KEY, JSON.stringify(clone(demoData)))
  window.dispatchEvent(new CustomEvent('tajo:data'))
}

export function getSession() {
  try { return JSON.parse(localStorage.getItem(SESSION_KEY)) } catch { return null }
}

export function setSession(session) {
  localStorage.setItem(SESSION_KEY, JSON.stringify(session))
  window.dispatchEvent(new CustomEvent('tajo:session'))
}

export function clearSession() {
  localStorage.removeItem(SESSION_KEY)
  window.dispatchEvent(new CustomEvent('tajo:session'))
}

export function mutate(mutator) {
  const data = loadData()
  const result = mutator(data)
  saveData(data)
  return result
}
