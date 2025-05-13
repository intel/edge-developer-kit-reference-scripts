import { createTextEmbeddingsAPI, deleteTextEmbeddingBySourceAPI } from "@/api/dataset";
import { CollectionConfig } from "payload";

export const RagDocuments: CollectionConfig = {
	slug: 'rag-documents', // The collection slug
	timestamps: true, // Automatically adds createdAt and updatedAt fields
	upload: {
		disableLocalStorage: true,
		mimeTypes: ['application/pdf'], 
	},
	fields: [
		{
      name: 'filename',
      type: 'text',
			required: true,
    },
		{
      name: 'description',
      type: 'text',
			required: false,
    },
	],
	hooks: {
    beforeDelete: [
      async ({ id }) => {
				try {
					// Delete the text embeddings stored in backend service
					const response = await deleteTextEmbeddingBySourceAPI(`${id}.pdf`);
					if (!response.status) throw new Error('Delete failed');
				} catch (error) {
					return {
						error: "ERROR: " + error
					}
				}
      },
    ],
		afterChange: [
			async ({ doc, operation, req }) => {
				if (operation === 'create' && req.file) {
					// Create the text embeddings in backend service
					try {
						const blob = new Blob([req.file.data], {type: req.file.mimetype});
						const file = new File([blob], `${doc.id}.pdf`, { type: req.file.mimetype });
						const formData = new FormData();
						formData.append('files', file);
	
						const response = await createTextEmbeddingsAPI(512, 0, formData);
	
						if (!response.status) throw new Error('Upload failed');
					} catch (error) {
						return {
              error: "ERROR: " + error
            }
					}
				}
				return doc
			}
		]
  },
};

export default RagDocuments;