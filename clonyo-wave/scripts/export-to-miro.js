#!/usr/bin/env node

/**
 * Export AWS Step Function to Miro Board
 * 
 * Usage:
 *   node scripts/export-to-miro.js
 * 
 * Environment Variables:
 *   MIRO_ACCESS_TOKEN - Your Miro API access token
 *   MIRO_BOARD_ID - Target Miro board ID
 */

const fs = require('fs');
const path = require('path');

// Configuration
const MIRO_API_BASE = 'https://api.miro.com/v2';
const ACCESS_TOKEN = process.env.MIRO_ACCESS_TOKEN;
const BOARD_ID = process.env.MIRO_BOARD_ID;

// Visual styling
const COLORS = {
  Pass: '#E6F3FF',      // Light blue
  Task: '#FFE6E6',      // Light red
  Choice: '#FFF4E6',    // Light orange
  Wait: '#F0E6FF',      // Light purple
  Succeed: '#E6FFE6',   // Light green
  Fail: '#FFE6E6',      // Light red
  Lambda: '#FF9999',    // Red
  DynamoDB: '#9999FF',  // Blue
  Transcribe: '#99FF99' // Green
};

const LAYOUT = {
  startX: 100,
  startY: 100,
  horizontalSpacing: 400,
  verticalSpacing: 200,
  nodeWidth: 300,
  nodeHeight: 100
};

/**
 * Parse Step Function definition
 */
function parseStepFunction() {
  const definitionPath = path.join(__dirname, '../step-function-definition.json');
  const data = JSON.parse(fs.readFileSync(definitionPath, 'utf8'));
  const definition = JSON.parse(data.definition);
  
  return {
    name: data.name,
    states: definition.States,
    startAt: definition.StartAt
  };
}

/**
 * Determine node color based on state type and resource
 */
function getNodeColor(state) {
  if (state.Type === 'Task') {
    if (state.Resource?.includes('lambda')) return COLORS.Lambda;
    if (state.Resource?.includes('dynamodb')) return COLORS.DynamoDB;
    if (state.Resource?.includes('transcribe')) return COLORS.Transcribe;
  }
  return COLORS[state.Type] || '#FFFFFF';
}

/**
 * Get node description
 */
function getNodeDescription(stateName, state) {
  const lines = [`Type: ${state.Type}`];
  
  if (state.Type === 'Task') {
    if (state.Resource?.includes('lambda')) {
      const fnName = state.Arguments?.FunctionName?.split(':').pop() || 'Lambda';
      lines.push(`Function: ${fnName}`);
    } else if (state.Resource?.includes('dynamodb')) {
      lines.push('Service: DynamoDB');
    } else if (state.Resource?.includes('transcribe')) {
      lines.push('Service: Transcribe');
    } else if (state.Resource?.includes('socialmessaging')) {
      lines.push('Service: WhatsApp');
    }
  }
  
  if (state.Type === 'Wait') {
    lines.push(`Duration: ${state.Seconds}s`);
  }
  
  if (state.Retry && state.Retry.length > 0) {
    lines.push(`Retry: ${state.Retry[0].MaxAttempts} attempts`);
  }
  
  return lines.join('\n');
}

/**
 * Build graph structure with positions
 */
function buildGraph(states, startAt) {
  const nodes = {};
  const edges = [];
  const visited = new Set();
  const levels = {};
  
  // Calculate levels (depth-first)
  function calculateLevel(stateName, level = 0, column = 0) {
    if (visited.has(stateName)) return;
    visited.add(stateName);
    
    if (!levels[level]) levels[level] = [];
    levels[level].push(stateName);
    
    const state = states[stateName];
    if (!state) return;
    
    // Create node
    nodes[stateName] = {
      name: stateName,
      state: state,
      level: level,
      column: levels[level].length - 1
    };
    
    // Process next states
    if (state.Next) {
      edges.push({ from: stateName, to: state.Next });
      calculateLevel(state.Next, level + 1);
    }
    
    if (state.Type === 'Choice') {
      state.Choices?.forEach((choice, idx) => {
        edges.push({ 
          from: stateName, 
          to: choice.Next,
          label: choice.Comment || `Choice ${idx + 1}`
        });
        calculateLevel(choice.Next, level + 1);
      });
      
      if (state.Default) {
        edges.push({ 
          from: stateName, 
          to: state.Default,
          label: 'Default'
        });
        calculateLevel(state.Default, level + 1);
      }
    }
  }
  
  calculateLevel(startAt);
  
  // Calculate positions
  Object.values(nodes).forEach(node => {
    node.x = LAYOUT.startX + (node.level * LAYOUT.horizontalSpacing);
    node.y = LAYOUT.startY + (node.column * LAYOUT.verticalSpacing);
  });
  
  return { nodes, edges };
}

/**
 * Create Miro shape (card)
 */
async function createMiroCard(boardId, node) {
  const response = await fetch(`${MIRO_API_BASE}/boards/${boardId}/shapes`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${ACCESS_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      data: {
        shape: 'round_rectangle',
        content: `<p><strong>${node.name}</strong></p><p>${getNodeDescription(node.name, node.state)}</p>`,
        style: {
          fillColor: getNodeColor(node.state),
          borderColor: '#000000',
          borderWidth: 2,
          fontSize: 14,
          textAlign: 'center'
        }
      },
      position: {
        x: node.x,
        y: node.y
      },
      geometry: {
        width: LAYOUT.nodeWidth,
        height: LAYOUT.nodeHeight
      }
    })
  });
  
  if (!response.ok) {
    throw new Error(`Failed to create card: ${response.statusText}`);
  }
  
  return await response.json();
}

/**
 * Create Miro connector
 */
async function createMiroConnector(boardId, fromId, toId, label) {
  const response = await fetch(`${MIRO_API_BASE}/boards/${boardId}/connectors`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${ACCESS_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      data: {
        startItem: { id: fromId },
        endItem: { id: toId },
        shape: 'curved',
        style: {
          strokeColor: '#000000',
          strokeWidth: 2
        },
        captions: label ? [{
          content: label,
          position: 0.5
        }] : []
      }
    })
  });
  
  if (!response.ok) {
    throw new Error(`Failed to create connector: ${response.statusText}`);
  }
  
  return await response.json();
}

/**
 * Create title text
 */
async function createTitle(boardId, title) {
  const response = await fetch(`${MIRO_API_BASE}/boards/${boardId}/texts`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${ACCESS_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      data: {
        content: `<h1>${title}</h1>`,
        style: {
          fontSize: 32,
          textAlign: 'center'
        }
      },
      position: {
        x: LAYOUT.startX + 200,
        y: LAYOUT.startY - 150
      }
    })
  });
  
  return await response.json();
}

/**
 * Main export function
 */
async function exportToMiro() {
  // Validate environment
  if (!ACCESS_TOKEN) {
    console.error('❌ MIRO_ACCESS_TOKEN environment variable is required');
    console.log('\nGet your token from: https://miro.com/app/settings/user-profile/apps');
    process.exit(1);
  }
  
  if (!BOARD_ID) {
    console.error('❌ MIRO_BOARD_ID environment variable is required');
    console.log('\nFind your board ID in the URL: https://miro.com/app/board/{BOARD_ID}/');
    process.exit(1);
  }
  
  console.log('🚀 Starting export to Miro...\n');
  
  // Parse Step Function
  console.log('📖 Parsing Step Function definition...');
  const { name, states, startAt } = parseStepFunction();
  console.log(`   Found ${Object.keys(states).length} states\n`);
  
  // Build graph
  console.log('🔨 Building graph structure...');
  const { nodes, edges } = buildGraph(states, startAt);
  console.log(`   Created ${Object.keys(nodes).length} nodes and ${edges.length} edges\n`);
  
  // Create title
  console.log('📝 Creating title...');
  await createTitle(BOARD_ID, name);
  
  // Create nodes
  console.log('🎨 Creating Miro cards...');
  const miroNodes = {};
  
  for (const [stateName, node] of Object.entries(nodes)) {
    const miroCard = await createMiroCard(BOARD_ID, node);
    miroNodes[stateName] = miroCard.id;
    console.log(`   ✓ ${stateName}`);
  }
  
  console.log('');
  
  // Create connectors
  console.log('🔗 Creating connectors...');
  for (const edge of edges) {
    const fromId = miroNodes[edge.from];
    const toId = miroNodes[edge.to];
    
    if (fromId && toId) {
      await createMiroConnector(BOARD_ID, fromId, toId, edge.label);
      console.log(`   ✓ ${edge.from} → ${edge.to}`);
    }
  }
  
  console.log('\n✅ Export completed successfully!');
  console.log(`\n🔗 View your board: https://miro.com/app/board/${BOARD_ID}/`);
}

// Run
exportToMiro().catch(error => {
  console.error('\n❌ Error:', error.message);
  process.exit(1);
});
