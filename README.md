# DFT Test Control Processor (TCP)
## High-Level Architectural Specification

### 1. Overview

The DFT Test Control Processor is an embedded system-on-chip component that orchestrates Design-for-Test operations across production testing, post-silicon validation, and in-field diagnostics. It provides autonomous test execution while maintaining external ATE compatibility through dual-access mechanisms.

**Core Value Proposition:** Reduce ATE dependency and test time by moving test intelligence on-die while ensuring the controller itself remains testable through standard DFT flows.

---

### 2. System Architecture
#### 2.0 Block Diagram
```
┌─────────────────────────────────────────────────────────────────┐
│                    DFT Test Control Processor                    │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐    │
│  │  RISC-V Core │  │ Pattern ROM/ │  │  Sequencer/Sched   │    │
│  │   (or FSM)   │──│    Flash     │──│   (SSN-aware)      │    │
│  └──────────────┘  └──────────────┘  └────────────────────┘    │
│         │                                      │                 │
│         │                                      │                 │
│  ┌──────┴──────────────────────────────────────┴──────┐         │
│  │           Test Mode Controller & Arbiter            │         │
│  │    (ATPG/MBIST/LBIST/Analog coordination)          │         │
│  └──────┬──────────────────────────────────────┬──────┘         │
│         │                                      │                 │
│  ┌──────┴──────┐  ┌──────────────┐  ┌────────┴─────────┐       │
│  │ Power/Clock │  │   Security   │  │  Diagnostics     │       │
│  │   Manager   │  │ Lock Manager │  │  Collector       │       │
│  └──────┬──────┘  └──────┬───────┘  └────────┬─────────┘       │
└─────────┼─────────────────┼───────────────────┼─────────────────┘
          │                 │                   │
          │                 │                   │
┌─────────┼─────────────────┼───────────────────┼─────────────────┐
│         ▼                 ▼                   ▼                  │
│  ┌─────────────┐   ┌────────────┐   ┌──────────────┐           │
│  │IJTAG Network│   │  Scan      │   │   Monitors   │           │
│  │   (1687)    │◄──┤  Chains    │   │ (PVT/Ring    │           │
│  └──────┬──────┘   │  (MUX)     │   │  Oscillator) │           │
│         │          └─────┬──────┘   └──────┬───────┘           │
│         │                │                  │                   │
│  ┌──────┴────────────────┴──────────────────┴────────┐          │
│  │                 Test Access Port                   │          │
│  │              (JTAG/IJTAG Interface)                │          │
│  └──────────────────────────┬─────────────────────────┘          │
│                             │                                    │
│  ┌──────────┐  ┌───────────┴──┐  ┌──────────┐  ┌──────────┐   │
│  │  MBIST   │  │   LBIST      │  │  ATPG    │  │  Analog  │   │
│  │ Engines  │  │   Engines    │  │  Logic   │  │   Test   │   │
│  └──────────┘  └──────────────┘  └──────────┘  └──────────┘   │
│                                                                  │
│                        DUT Fabric                                │
└──────────────────────────────────────────────────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │   External ATE  │
                    │  (when needed)  │
                    └─────────────────┘
```

#### 2.1 Processor Core
- **ISA:** RISC-V RV32I or simple FSM-based sequencer
- **Purpose:** Execute test sequences, make adaptive decisions, coordinate modes
- **Rationale:** RISC-V provides programmability for flexibility; FSM alternative for minimal area/power

#### 2.2 Pattern Storage
- **Medium:** On-chip ROM for boot/critical patterns, Flash for updateable content
- **Capacity:** Sized for compressed pattern sets (decompression in sequencer)
- **Access:** Read-only during normal operation, JTAG-programmable for Flash

#### 2.3 Test Sequencer & Scheduler
- **Function:** Decompress patterns, apply with SSN-aware timing control
- **SSN Management:** Track simultaneous switching budget across clock domains
- **Adaptivity:** Adjust based on PVT monitor feedback

---

### 3. Functional Blocks

#### 3.1 Test Mode Controller & Arbiter
**Responsibilities:**
- Coordinate transitions between ATPG, MBIST, LBIST, analog test modes
- Manage resource conflicts (shared scan chains, power domains)
- Implement safe entry/exit protocols for each mode

**Mode State Machine:**
```
IDLE → MODE_ENTRY → TEST_EXEC → RESULT_COLLECT → MODE_EXIT → IDLE
```

#### 3.2 Power & Clock Manager
**Capabilities:**
- Dynamic voltage/frequency adjustment during test
- SSN mitigation through phased clock domain activation
- Thermal throttling based on temperature sensor feedback
- Voltage island coordination (some powered, some isolated)

**Integration Points:**
- Process monitors (ring oscillators, voltage sensors)
- Clock gating infrastructure
- Power management unit (PMU)

#### 3.3 Security & Lock Manager
**Features:**
- Scan chain access control (prevent reverse engineering)
- Debug authentication (production vs. development keys)
- Test mode authorization before IJTAG access
- Secure boot for TCP firmware updates

**Security Model:** Hierarchical—external JTAG always accessible for recovery, but scan/debug features require authentication.

#### 3.4 Diagnostics Collector
**Data Aggregation:**
- Fail logs from distributed BIST engines
- Coverage metrics from scan operations
- Aging indicators (NBTI, HCI monitors)
- Binning data for yield analysis

**Compression:** On-chip compression before external read to minimize test data volume

---

### 4. Interface Architecture

#### 4.1 IJTAG Network (IEEE 1687)
- **Role:** TCP acts as instrument manager in retargetable scan network
- **Topology:** Star or hierarchical based on chip floor plan
- **Reconfiguration:** Dynamic scan path composition per test mode

#### 4.2 Test Access Port (TAP)
- **Primary:** IEEE 1149.1 (JTAG) for external ATE interface
- **Secondary:** IJTAG internal distribution
- **Dual-Mode:**
  - **Bypass Mode:** Direct ATE → DUT (TCP inactive)
  - **Autonomous Mode:** ATE → TCP → DUT orchestration

#### 4.3 Scan Chain Interface
- **Topology:** Multiplexed access to functional scan chains
- **Control:** TCP selects active chains via IJTAG routing
- **Observation:** Parallel signature analysis for fast compare

---

### 5. Test Flow & Bootstrapping
#### 5.0 TCP Testings
```
┌─────────────┐
│ External    │──→ Direct JTAG access (bypass TCP)
│ JTAG/ATE    │
└─────────────┘
       │
       ├──→ TCP structural test (Phase 0)
       │
       └──→ TCP functional verification (Phase 1-2)
                     ↓
              ┌─────────────┐
              │     TCP     │──→ Normal operation (Phase 3)
              │  (verified) │
              └─────────────┘
```

#### 5.1 TCP Self-Test Sequence

**Phase 0: Structural Verification**
- External JTAG drives ATPG patterns into TCP logic
- TCP is passive DUT, no execution required
- **Coverage Target:** >95% stuck-at, transition faults

**Phase 1: Functional BIST**
- Boot ROM executes microprocessor self-test
- Validates: ALU, register file, branch logic, memory interface
- **Pass Criteria:** Signature match in dedicated output register

**Phase 2: Infrastructure Checkout**
- TCP executes minimal test command (shift pattern, read result)
- External JTAG monitors to verify TCP → IJTAG → Scan path
- **Validates:** TAP interface, mode switching, basic arbitration

**Phase 3: Full Orchestration**
- TCP now trusted to manage production test flows
- ATE transitions to supervisory role

#### 5.2 Production Test Flow
```
1. ATE loads test program into TCP Flash (one-time)
2. ATE triggers TCP execution via JTAG command
3. TCP sequences through:
   - ATPG patterns
   - Memory BIST
   - Logic BIST
   - Analog test (if embedded ADC present)
4. TCP writes pass/fail + diagnostics to output registers
5. ATE reads final result (milliseconds vs. full pattern scan)
```

---

### 6. Analog Test Integration

#### 6.1 Measurement Strategy

**Option A: Embedded ADC Path**
```
Analog Block → Analog Mux → ADC (8-12 bit) → TCP
                 ↑
         Stimulus (DAC/RefGen)
```
- **Use Case:** High-volume screening, in-field diagnostics
- **Tradeoff:** ADC needs calibration, limited precision

**Option B: Comparator-Based**
```
Analog Block → Comparator → Digital Flag → TCP
                 ↑
            Threshold (RefGen)
```
- **Use Case:** Simple pass/fail (voltage > spec?)
- **Tradeoff:** Binary decision only, no measurement data

**Option C: ATE Precision Instruments**
```
Analog Block → Test Mux → External Pin → ATE
                              ↑
                       (TCP coordinates)
```
- **Use Case:** Characterization, margin analysis
- **Tradeoff:** Slower, requires analog test channels

**Recommended Hybrid:** Comparators for production, reserve ATE for characterization/debug.

#### 6.2 Additional Analog Components
- **Analog test bus:** Route internal nodes to observation points
- **Built-in loopback:** Stimulus → response without pin access
- **Time-to-Digital Converters (TDC):** For jitter/timing measurements (I/O, PLLs)

---

### 7. Key Design Principles

#### 7.1 Fail-Safe Access
- **JTAG bypass always available:** TCP failure doesn't brick chip
- **External override:** ATE can force modes if TCP malfunctions
- **Watchdog monitoring:** Detects TCP hangs, triggers recovery

#### 7.2 Composability
- TCP is another IJTAG instrument, not special-cased infrastructure
- Standard IEEE 1687 PDL description for tool compatibility
- Modular test blocks (BIST engines) with uniform interfaces

#### 7.3 Scalability
- Design supports chiplet architectures (TCP per die or shared)
- Pattern storage sized per product (ROM for base, Flash for variants)
- Diagnostics collector bandwidth scales with BIST engine count

---

### 8. Post-Silicon Applications

Beyond production test, TCP infrastructure enables:

**In-Field Diagnostics:**
- Periodic self-test using existing BIST engines
- Aging monitor readout (NBTI, HCI sensors)
- Failure analysis via partial scan access

**Adaptive Operation:**
- Process corner detection → binning for speed/power grades
- Voltage/temperature tracking → dynamic margin adjustment
- Wear-out prediction via historical monitor data

**Security:**
- Scan lock prevents IP extraction after deployment
- Debug authentication gates field access to test features

---

### 9. Open Issues / Future Work

- **Multi-die coordination:** How do multiple TCPs synchronize in chiplet systems?
- **Pattern update mechanism:** OTA firmware updates for Flash-based patterns?
- **AI/ML integration:** Adaptive test selection based on volume learning?
- **Standardization:** Push for IEEE standard beyond 1687 (test controller IP)?

---

### 10. References

- IEEE 1149.1: Standard Test Access Port and Boundary-Scan Architecture
- IEEE 1687: Standard for Access and Control of Instrumentation Embedded within a Semiconductor Device
- IEEE 1500: Standard Testability Method for Embedded Core-based Integrated Circuits

---

**Document Version:** 1.0
**Last Updated:** December 2025
**Owner:** Architecture Team

