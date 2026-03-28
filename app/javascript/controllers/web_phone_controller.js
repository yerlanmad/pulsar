import { Controller } from "@hotwired/stimulus"
import JsSIP from "jssip"

export default class extends Controller {
  static targets = [
    "status", "panel", "toggleButton",
    "dialInput", "callButton", "hangupButton", "answerButton", "rejectButton",
    "muteButton", "audio", "incomingAlert", "dialpad",
    "callerInfo", "callTimer"
  ]

  static values = {
    credentialsUrl: { type: String, default: "/web_phone/credentials" }
  }

  // State: idle | registering | registered | ringing_in | ringing_out | in_call
  connect() {
    this.state = "idle"
    this.ua = null
    this.currentSession = null
    this.reconnectAttempts = 0
    this.maxReconnectAttempts = 10
    this.callTimerInterval = null
    this.callStartTime = null

    this.fetchCredentialsAndStart()
  }

  disconnect() {
    this.stopCallTimer()
    if (this.ua) {
      this.ua.stop()
      this.ua = null
    }
  }

  async fetchCredentialsAndStart() {
    try {
      const response = await fetch(this.credentialsUrlValue, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return

      const creds = await response.json()
      this.startUA(creds)
    } catch (e) {
      console.error("[WebPhone] Failed to fetch credentials:", e)
      this.updateState("idle")
    }
  }

  startUA({ sip_user, sip_password, sip_domain, ws_url }) {
    const socket = new JsSIP.WebSocketInterface(ws_url)

    const config = {
      sockets: [socket],
      uri: `sip:${sip_user}@${sip_domain}`,
      password: sip_password,
      display_name: sip_user,
      register: true,
      register_expires: 300,
      session_timers: false,
      connection_recovery_min_interval: 2,
      connection_recovery_max_interval: 30
    }

    this.ua = new JsSIP.UA(config)

    this.ua.on("connecting", () => {
      this.updateState("registering")
    })

    this.ua.on("connected", () => {
      this.reconnectAttempts = 0
    })

    this.ua.on("registered", () => {
      this.updateState("registered")
    })

    this.ua.on("unregistered", () => {
      if (this.state !== "in_call") {
        this.updateState("idle")
      }
    })

    this.ua.on("registrationFailed", (e) => {
      console.error("[WebPhone] Registration failed:", e.cause)
      this.updateState("idle")
    })

    this.ua.on("disconnected", () => {
      if (this.state !== "in_call") {
        this.updateState("idle")
      }
      this.scheduleReconnect()
    })

    this.ua.on("newRTCSession", (data) => {
      this.handleNewSession(data)
    })

    this.ua.start()
  }

  scheduleReconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) return

    this.reconnectAttempts++
    const delay = Math.min(Math.pow(2, this.reconnectAttempts) * 1000, 30000)
    console.log(`[WebPhone] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`)
    setTimeout(() => {
      if (this.ua && !this.ua.isConnected()) {
        this.ua.start()
      }
    }, delay)
  }

  handleNewSession(data) {
    const session = data.session

    if (this.currentSession) {
      session.terminate({ status_code: 486, reason_phrase: "Busy Here" })
      return
    }

    this.currentSession = session

    if (session.direction === "incoming") {
      this.updateState("ringing_in")
      this.showCallerInfo(session.remote_identity.display_name || session.remote_identity.uri.user)
      this.playRingtone()
    }

    session.on("accepted", () => {
      this.updateState("in_call")
      this.stopRingtone()
      this.startCallTimer()
    })

    session.on("confirmed", () => {
      this.updateState("in_call")
      this.attachRemoteAudio(session)
    })

    session.on("ended", () => {
      this.endCall()
    })

    session.on("failed", (e) => {
      console.warn("[WebPhone] Call failed:", e.cause)
      this.endCall()
    })

    session.on("peerconnection", (data) => {
      data.peerconnection.addEventListener("track", (event) => {
        if (this.hasAudioTarget) {
          this.audioTarget.srcObject = event.streams[0]
        }
      })
    })
  }

  attachRemoteAudio(session) {
    if (!this.hasAudioTarget || !session.connection) return
    const receivers = session.connection.getReceivers()
    if (receivers.length > 0) {
      const stream = new MediaStream()
      receivers.forEach(r => {
        if (r.track) stream.addTrack(r.track)
      })
      this.audioTarget.srcObject = stream
    }
  }

  // Actions
  dial() {
    if (!this.ua || !this.ua.isRegistered()) return
    if (!this.hasDialInputTarget) return

    const number = this.dialInputTarget.value.trim()
    if (!number) return

    this.updateState("ringing_out")

    const options = {
      mediaConstraints: { audio: true, video: false },
      rtcOfferConstraints: { offerToReceiveAudio: true, offerToReceiveVideo: false },
      pcConfig: this.pcConfig()
    }

    this.ua.call(`sip:${number}@${this.ua.configuration.uri.host}`, options)
  }

  answer() {
    if (!this.currentSession) return

    this.stopRingtone()
    this.currentSession.answer({
      mediaConstraints: { audio: true, video: false },
      pcConfig: this.pcConfig()
    })
  }

  reject() {
    if (!this.currentSession) return
    this.stopRingtone()
    this.currentSession.terminate({ status_code: 603, reason_phrase: "Decline" })
  }

  hangup() {
    if (!this.currentSession) return
    this.currentSession.terminate()
  }

  toggleMute() {
    if (!this.currentSession) return

    if (this.currentSession.isMuted().audio) {
      this.currentSession.unmute({ audio: true })
      if (this.hasMuteButtonTarget) {
        this.muteButtonTarget.dataset.muted = "false"
        this.muteButtonTarget.textContent = "Mute"
      }
    } else {
      this.currentSession.mute({ audio: true })
      if (this.hasMuteButtonTarget) {
        this.muteButtonTarget.dataset.muted = "true"
        this.muteButtonTarget.textContent = "Unmute"
      }
    }
  }

  sendDtmf(event) {
    const digit = event.currentTarget.dataset.digit
    if (!digit || !this.currentSession) return
    this.currentSession.sendDTMF(digit)
    if (this.hasDialInputTarget) {
      this.dialInputTarget.value += digit
    }
  }

  togglePanel() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.toggle("hidden")
    }
  }

  dialKey(event) {
    const key = event.currentTarget.dataset.key
    if (!key || !this.hasDialInputTarget) return
    this.dialInputTarget.value += key
  }

  backspace() {
    if (!this.hasDialInputTarget) return
    this.dialInputTarget.value = this.dialInputTarget.value.slice(0, -1)
  }

  // Private helpers
  pcConfig() {
    return {
      iceServers: [
        { urls: "stun:stun.l.google.com:19302" },
        { urls: "stun:stun1.l.google.com:19302" }
      ],
      iceTransportPolicy: "all"
    }
  }

  endCall() {
    this.currentSession = null
    this.stopRingtone()
    this.stopCallTimer()
    if (this.hasCallerInfoTarget) this.callerInfoTarget.textContent = ""
    if (this.hasDialInputTarget) this.dialInputTarget.value = ""
    if (this.ua && this.ua.isRegistered()) {
      this.updateState("registered")
    } else {
      this.updateState("idle")
    }
  }

  updateState(newState) {
    this.state = newState
    this.element.dataset.state = newState

    if (this.hasStatusTarget) {
      const labels = {
        idle: "Offline",
        registering: "Connecting...",
        registered: "Online",
        ringing_in: "Incoming Call",
        ringing_out: "Calling...",
        in_call: "In Call"
      }
      this.statusTarget.textContent = labels[newState] || newState
    }
  }

  showCallerInfo(caller) {
    if (this.hasCallerInfoTarget) {
      this.callerInfoTarget.textContent = caller
    }
  }

  playRingtone() {
    // Simple oscillator ringtone
    try {
      this.ringtoneCtx = new AudioContext()
      this.ringtoneInterval = setInterval(() => {
        const osc = this.ringtoneCtx.createOscillator()
        const gain = this.ringtoneCtx.createGain()
        osc.connect(gain)
        gain.connect(this.ringtoneCtx.destination)
        osc.frequency.value = 440
        gain.gain.value = 0.3
        osc.start()
        osc.stop(this.ringtoneCtx.currentTime + 0.3)
      }, 1000)
    } catch (e) {
      // AudioContext not available
    }
  }

  stopRingtone() {
    if (this.ringtoneInterval) {
      clearInterval(this.ringtoneInterval)
      this.ringtoneInterval = null
    }
    if (this.ringtoneCtx) {
      this.ringtoneCtx.close()
      this.ringtoneCtx = null
    }
  }

  startCallTimer() {
    this.callStartTime = Date.now()
    this.callTimerInterval = setInterval(() => {
      if (this.hasCallTimerTarget) {
        const elapsed = Math.floor((Date.now() - this.callStartTime) / 1000)
        const min = String(Math.floor(elapsed / 60)).padStart(2, "0")
        const sec = String(elapsed % 60).padStart(2, "0")
        this.callTimerTarget.textContent = `${min}:${sec}`
      }
    }, 1000)
  }

  stopCallTimer() {
    if (this.callTimerInterval) {
      clearInterval(this.callTimerInterval)
      this.callTimerInterval = null
    }
    this.callStartTime = null
    if (this.hasCallTimerTarget) {
      this.callTimerTarget.textContent = "00:00"
    }
  }
}
