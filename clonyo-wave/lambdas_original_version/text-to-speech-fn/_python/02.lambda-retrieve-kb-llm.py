import boto3
import os
import json



def get_knowledge_base_content(message=None, id_kbase='WLSH0SUKNB'):
    session = boto3.Session(region_name='eu-west-1')
    client = session.client('bedrock-agent-runtime')
    response = client.retrieve(
        knowledgeBaseId=id_kbase,
        retrievalConfiguration={
            "vectorSearchConfiguration": {"numberOfResults": 4}
        },
        retrievalQuery={"text": message}
    )
    docs_content = "\n\n".join([doc['content']['text'] for doc in response['retrievalResults']])
    return docs_content

def build_prompt(domanda, text):
    system_prompt = "Agisci come Luca Mazzucchelli, psicologo, psicoterapeuta e divulgatore italiano. Rispondi alla {domanda} con chiarezza, empatia e uno stile motivazionale. Date le informazioni rilevanti dalla domanda {text} devi generarmi una risposta come farebbe un psicologo. Utilizza i seguenti tag SSML per modulare la voce: <emphasis> per enfatizzare concetti chiave. <break time=\"x.xs\"/> per inserire pause naturali. <prosody rate=\"...\" pitch=\"...\"> per variare velocità e intonazione."
    user_prompt = "\n\nHuman: {domanda}\n\nAssistant:"
    prompt_text = system_prompt + user_prompt
    return prompt_text


def lambda_handler(event, context):
    session = boto3.Session(region_name='eu-west-3')
    bedrock_runtime = session.client('bedrock-runtime')
    domanda = event['message']
    text = get_knowledge_base_content(domanda)
    prompt = build_prompt(domanda, text)
    response = bedrock_runtime.invoke_model(
        modelId="eu.anthropic.claude-3-5-sonnet-20240620-v1:0",
        body=bytes(json.dumps({"prompt": prompt, "temperature": 0.5,"max_tokens_to_sample":4096}), encoding='utf-8'),
        contentType="application/json",
        accept="application/json"
    )
    result = json.loads(response['body'].read())
    return {
        'statusCode': 200,
        'body': result
    }
